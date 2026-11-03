import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'
import { HandlerError } from '../../../src/shared/errors'
import type { AiCommitFilesInput, AiSettings } from '../../../src/shared/ipc/integrations'

const mocks = vi.hoisted(() => ({
  handlers: new Map<string, (...args: unknown[]) => unknown>(),
  getPath: vi.fn(() => 'user-data'),
  crypto: {},
  getRepository: vi.fn(() => ({ path: 'repository-root' })),
  buildPayload: vi.fn(async () => 'reviewed diff'),
  get: vi.fn<() => Promise<AiSettings>>(),
  update: vi.fn(),
  apiKey: vi.fn<() => Promise<string | undefined>>().mockResolvedValue('private-key'),
  store: vi.fn(),
}))
vi.mock('electron', () => ({ app: { getPath: mocks.getPath }, safeStorage: mocks.crypto }))
vi.mock('../../../src/main/ipc', () => ({
  handle: (channel: string, handler: (...args: unknown[]) => unknown) =>
    mocks.handlers.set(channel, handler),
}))
vi.mock('../../../src/main/store/repositories', () => ({ getRepository: mocks.getRepository }))
vi.mock('../../../src/main/ai/payload', () => ({ buildPayload: mocks.buildPayload }))
vi.mock('../../../src/main/ai/settings', () => ({
  AiSettingsStore: class {
    constructor(...args: unknown[]) {
      mocks.store(...args)
    }
    get = mocks.get
    update = mocks.update
    apiKey = mocks.apiKey
  },
}))
import { register } from '../../../src/main/ai/register'

const input: AiCommitFilesInput = {
  files: [{ path: 'one.txt', selection: { defaultSelectionType: 'all', divergingLines: [] } }],
}
const settings: AiSettings = { provider: 'anthropic', hasApiKey: true, model: 'custom-model' }
const event = { sender: { id: 7 } }
function call(channel: string, ...args: unknown[]) {
  return mocks.handlers.get(channel)!(event, ...args)
}
function setup() {
  const anthropic = {
    generate: vi.fn(async () => ({ summary: 'A summary', description: 'A description' })),
  }
  const compatible = {
    generate: vi.fn(async () => ({ summary: 'Local summary', description: 'Local description' })),
  }
  register({ anthropic, 'openai-compatible': compatible })
  return { anthropic, compatible }
}

beforeEach(() => {
  vi.clearAllMocks()
  mocks.handlers.clear()
  mocks.get.mockResolvedValue(settings)
  mocks.buildPayload.mockResolvedValue('reviewed diff')
  mocks.apiKey.mockResolvedValue('private-key')
  mocks.update.mockResolvedValue(settings)
})
afterEach(() => vi.restoreAllMocks())

describe('AI IPC registration', () => {
  it('registers all four channels and creates a userData safeStorage store', () => {
    setup()
    expect([...mocks.handlers.keys()].sort()).toEqual([
      'ai:generateCommitMessage',
      'ai:getSettings',
      'ai:previewPayload',
      'ai:updateSettings',
    ])
    expect(mocks.getPath).toHaveBeenCalledWith('userData')
    expect(mocks.store).toHaveBeenCalledWith('user-data', mocks.crypto)
  })
  it('forwards settings updates but returns only store public settings', async () => {
    setup()
    expect(await call('ai:getSettings')).toEqual(settings)
    const patch = { provider: 'anthropic', apiKey: 'private-key' }
    const response = await call('ai:updateSettings', patch)
    expect(mocks.update).toHaveBeenCalledWith(patch)
    expect(response).toEqual(settings)
    expect(JSON.stringify(response)).not.toContain('private-key')
    expect(response).not.toHaveProperty('apiKey')
    expect(mocks.apiKey).not.toHaveBeenCalled()
  })
  it('sends exactly the reviewed text to an injected provider', async () => {
    const { anthropic, compatible } = setup()
    expect(await call('ai:previewPayload', 'repo-id', input)).toBe('reviewed diff')
    expect(await call('ai:generateCommitMessage', 'repo-id', input)).toEqual({
      summary: 'A summary',
      description: 'A description',
    })
    expect(mocks.getRepository).toHaveBeenCalledWith('repo-id')
    expect(mocks.buildPayload).toHaveBeenCalledWith('repository-root', input)
    expect(anthropic.generate).toHaveBeenCalledWith(settings, 'private-key', 'reviewed diff')
    expect(compatible.generate).not.toHaveBeenCalled()
  })
  it('supports a keyless local provider', async () => {
    const local: AiSettings = { provider: 'openai-compatible', hasApiKey: false }
    mocks.get.mockResolvedValue(local)
    mocks.apiKey.mockResolvedValue(undefined)
    const { anthropic, compatible } = setup()
    await call('ai:previewPayload', 'repo-id', input)
    expect(await call('ai:generateCommitMessage', 'repo-id', input)).toEqual({
      summary: 'Local summary',
      description: 'Local description',
    })
    expect(compatible.generate).toHaveBeenCalledWith(local, undefined, 'reviewed diff')
    expect(anthropic.generate).not.toHaveBeenCalled()
  })
  it('requires a preview before sending', async () => {
    const { anthropic } = setup()
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).not.toHaveBeenCalled()
    expect(mocks.apiKey).not.toHaveBeenCalled()
  })
  it('rejects changed diff content before reading the key or invoking a provider', async () => {
    const { anthropic } = setup()
    await call('ai:previewPayload', 'repo-id', input)
    mocks.buildPayload.mockResolvedValue('changed diff')
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).not.toHaveBeenCalled()
    expect(mocks.apiKey).not.toHaveBeenCalled()
  })
  it('rejects changed selections and repository ids', async () => {
    const { anthropic } = setup()
    await call('ai:previewPayload', 'repo-id', input)
    await expect(call('ai:generateCommitMessage', 'repo-id', { files: [] })).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    await call('ai:previewPayload', 'repo-id', input)
    await expect(call('ai:generateCommitMessage', 'another-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).not.toHaveBeenCalled()
  })
  it('expires previews after ten minutes', async () => {
    const { anthropic } = setup()
    const now = vi.spyOn(Date, 'now').mockReturnValue(1000)
    await call('ai:previewPayload', 'repo-id', input)
    now.mockReturnValue(601001)
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).not.toHaveBeenCalled()
  })
  it('consumes the preview after one generation', async () => {
    const { anthropic } = setup()
    await call('ai:previewPayload', 'repo-id', input)
    await call('ai:generateCommitMessage', 'repo-id', input)
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).toHaveBeenCalledTimes(1)
  })
  it('isolates each sender preview', async () => {
    const { anthropic } = setup()
    await call('ai:previewPayload', 'repo-id', input)
    await expect(
      mocks.handlers.get('ai:generateCommitMessage')!({ sender: { id: 8 } }, 'repo-id', input)
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
    expect(anthropic.generate).not.toHaveBeenCalled()
    await call('ai:generateCommitMessage', 'repo-id', input)
    expect(anthropic.generate).toHaveBeenCalledTimes(1)
  })
  it('rejects a disabled provider', async () => {
    mocks.get.mockResolvedValue({ provider: 'none', hasApiKey: false })
    const { anthropic, compatible } = setup()
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).not.toHaveBeenCalled()
    expect(compatible.generate).not.toHaveBeenCalled()
  })
  it('sanitizes unexpected provider errors and consumes the preview on failure', async () => {
    const { anthropic } = setup()
    anthropic.generate.mockRejectedValue(new Error('private-key reviewed diff'))
    await call('ai:previewPayload', 'repo-id', input)
    const error = await Promise.resolve(call('ai:generateCommitMessage', 'repo-id', input)).catch(
      (failure: unknown) => failure
    )
    expect(error).toMatchObject({
      kind: 'internal',
      message: 'Could not generate a commit message.',
    })
    expect(String(error)).not.toContain('private-key')
    expect(String(error)).not.toContain('reviewed diff')
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    expect(anthropic.generate).toHaveBeenCalledTimes(1)
  })
  it('preserves a sanitized typed provider error', async () => {
    const { anthropic } = setup()
    anthropic.generate.mockRejectedValue(new HandlerError('network', 'Unavailable'))
    await call('ai:previewPayload', 'repo-id', input)
    await expect(call('ai:generateCommitMessage', 'repo-id', input)).rejects.toMatchObject({
      kind: 'network',
      message: 'Unavailable',
    })
  })
})
