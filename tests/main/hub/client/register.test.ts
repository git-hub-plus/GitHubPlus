import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, expect, it, vi } from 'vitest'
import type { GitAuthProvider } from '../../../../src/main/git/core'

const state = vi.hoisted(() => ({
  directory: '',
  handlers: new Map<string, (...args: unknown[]) => unknown>(),
  socket: { on: vi.fn(), bind: vi.fn(), unref: vi.fn(), close: vi.fn() },
  quit: vi.fn(),
  broadcast: vi.fn(),
  auth: vi.fn(),
}))
vi.mock('electron', () => ({ app: { getPath: () => state.directory, once: state.quit } }))
vi.mock('node:dgram', () => ({ createSocket: () => state.socket }))
vi.mock('../../../../src/main/ipc', () => ({
  handle: (channel: string, handler: (...args: unknown[]) => unknown) =>
    state.handlers.set(channel, handler),
  broadcast: state.broadcast,
}))
vi.mock('../../../../src/main/log', () => ({ log: { warn: vi.fn() } }))
vi.mock('../../../../src/main/git/core', async (original) => ({
  ...(await original<object>()),
  registerGitAuthProvider: state.auth,
}))
vi.mock('../../../../src/main/store/repositories', async (original) => ({
  ...(await original<object>()),
  loadRepositories: vi.fn(async () => []),
  listRepositories: () => [{ path: 'C:/team', remoteUrl: 'http://192.168.0.2:8765/team.git' }],
}))

import { HubApi } from '../../../../src/main/hub/client/api'
import { register } from '../../../../src/main/hub/client/register'
import { groupForRemote, loadRepositories } from '../../../../src/main/store/repositories'
import { repository, run } from '../../git/helpers'

afterEach(async () => {
  const quit = state.quit.mock.calls[0]?.[1] as (() => void) | undefined
  quit?.()
  vi.restoreAllMocks()
  if (state.directory) await rm(state.directory, { recursive: true, force: true })
})

it('registers client IPC, UDP discovery, URL grouping, regrouping and hub credential overrides', async () => {
  state.directory = await mkdtemp(join(tmpdir(), 'ghp-hub-register-'))
  const removeAuth = vi.fn()
  state.auth.mockReturnValue(removeAuth)
  vi.spyOn(HubApi.prototype, 'info').mockResolvedValue({ name: 'manual', version: '1' })
  register()
  expect(state.socket.bind).toHaveBeenCalledWith(47321)
  const call = (name: string, ...args: unknown[]) => state.handlers.get(name)!({}, ...args)
  expect(await call('hub:discovered')).toEqual([])
  const onMessage = state.socket.on.mock.calls.find(([event]) => event === 'message')![1] as (
    packet: Buffer,
    remote: { address: string }
  ) => void
  onMessage(
    Buffer.from(JSON.stringify({ type: 'ghp-hub', name: 'office', port: 8765, version: '1' })),
    { address: '192.168.0.2' }
  )
  await vi.waitFor(() =>
    expect(state.broadcast).toHaveBeenCalledWith(
      'hub:discoveredChanged',
      expect.arrayContaining([expect.objectContaining({ online: true })])
    )
  )
  expect(groupForRemote('http://192.168.0.2:8765/team.git')).toBe('hub')
  expect(groupForRemote('http://192.168.0.2:8766/team.git')).toBe('local')
  expect(groupForRemote('https://github.com/org/team.git')).toBe('github')
  await vi.waitFor(() => expect(loadRepositories).toHaveBeenCalled())
  const provider = state.auth.mock.calls[0][0] as GitAuthProvider
  expect(provider(['clone', 'http://192.168.0.2:8765/team.git'], 'C:/other')?.configArgs).toContain(
    'credential.helper='
  )
  expect(provider(['push', 'origin'], 'C:/team')?.configArgs).toContain(
    'credential.http://192.168.0.2:8765.helper='
  )
  expect(provider(['fetch', 'github'], 'C:/team')?.configArgs).not.toContain('credential.helper=')
  expect(provider(['fetch', 'github'], 'C:/other')?.configArgs).not.toContain('credential.helper=')
  expect(provider(['fetch', 'hub'], 'C:/other')?.configArgs).toContain(
    'credential.http://192.168.0.2:8765.helper='
  )
  const root = await repository()
  await run(root, ['config', 'credential.helper', 'existing-helper'])
  const configArgs = provider(['push', 'origin'], root)?.configArgs ?? []
  expect(
    await run(root, [
      ...configArgs,
      'config',
      '--get-urlmatch',
      'credential.helper',
      'http://192.168.0.2:8765/team.git',
    ])
  ).toBe('')
  expect(
    await run(root, [
      ...configArgs,
      'config',
      '--get-urlmatch',
      'credential.helper',
      'https://github.com/org/team.git',
    ])
  ).toBe('existing-helper')
  await call('hub:addManual', '192.168.0.3:8765')
  expect(groupForRemote('http://192.168.0.3:8765/team.git')).toBe('hub')
  await call('hub:removeManual', 'http://192.168.0.3:8765')
  expect(groupForRemote('http://192.168.0.3:8765/team.git')).toBe('local')
  const expected = [
    'hub:discovered',
    'hub:addManual',
    'hub:removeManual',
    'hub:listRemoteRepositories',
    'hub:createRemoteRepository',
    'hub:remoteLog',
    'hub:remoteCommitFiles',
    'hub:remoteCommitDiff',
    'hub:publish',
  ]
  expect([...state.handlers.keys()].sort()).toEqual(expected.sort())
})
