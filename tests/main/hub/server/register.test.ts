import { afterEach, expect, it, vi } from 'vitest'
import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import type { HubSettings } from '../../../../src/shared/ipc/hub'

const mocks = vi.hoisted(() => ({
  root: '',
  handlers: new Map<string, (...args: unknown[]) => unknown>(),
  login: vi.fn(),
  broadcast: vi.fn(),
}))
vi.mock('electron', () => ({
  app: { getPath: () => mocks.root, getVersion: () => 'test', setLoginItemSettings: mocks.login },
}))
vi.mock('../../../../src/main/ipc', () => ({
  handle: (name: string, handler: (...args: unknown[]) => unknown) =>
    mocks.handlers.set(name, handler),
  broadcast: mocks.broadcast,
}))
vi.mock('../../../../src/main/log', () => ({
  log: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}))
vi.mock('../../../../src/main/hub/server/announcer', () => ({ startAnnouncer: () => () => {} }))

afterEach(async () => {
  await rm(mocks.root, { recursive: true, force: true })
})
it('persists defaults, serializes updates, restarts the listener and applies login settings', async () => {
  mocks.root = await mkdtemp(join(tmpdir(), 'ghp-hub-settings-'))
  const { register, updateHubSettings, getHub, stopHub } =
    await import('../../../../src/main/hub/server/register')
  register()
  const settings = (await mocks.handlers.get('hub:getSettings')!(null)) as HubSettings
  expect(settings).toMatchObject({
    enabled: false,
    port: 8765,
    rootDirectory: join(mocks.root, 'GitHubPlus Hub'),
    keepRunningInTray: true,
    startWithWindows: false,
  })
  expect(settings.name).toMatch(/ 허브$/)
  try {
    // Let the OS allocate test ports through the core; IPC settings correctly reject port zero.
    await expect(updateHubSettings({ port: 0 })).rejects.toThrow('Invalid hub settings')
    const { createServer } = await import('node:net')
    const probe = createServer()
    await new Promise<void>((resolve) => probe.listen(0, resolve))
    const address = probe.address()
    const port = typeof address === 'object' && address ? address.port : 0
    await new Promise<void>((resolve) => probe.close(() => resolve()))
    await updateHubSettings({ enabled: true, port, startWithWindows: true })
    expect(getHub()!.status()).toMatchObject({ running: true, port })
    await Promise.all([
      updateHubSettings({ name: 'Renamed' }),
      updateHubSettings({ keepRunningInTray: false }),
    ])
    expect(getHub()!.settings).toMatchObject({ name: 'Renamed', keepRunningInTray: false })
    await updateHubSettings({ enabled: false, port: 8766 })
    expect(getHub()!.status()).toMatchObject({ running: false, port: 8766 })
    expect(JSON.parse(await readFile(join(mocks.root, 'hub-settings.json'), 'utf8'))).toMatchObject(
      { enabled: false, name: 'Renamed', startWithWindows: true, port: 8766 }
    )
    expect(mocks.login).toHaveBeenLastCalledWith({ openAtLogin: true })
    expect(mocks.broadcast).toHaveBeenCalledWith(
      'hub:statusChanged',
      expect.objectContaining({ running: true })
    )
  } finally {
    await stopHub()
  }
})
