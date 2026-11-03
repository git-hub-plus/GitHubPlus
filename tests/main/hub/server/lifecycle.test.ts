import { EventEmitter } from 'node:events'
import { expect, it, vi } from 'vitest'
import type { BrowserWindow } from 'electron'

const mocks = vi.hoisted(() => ({
  running: true,
  keep: true,
  menu: vi.fn(),
  destroy: vi.fn(),
  update: vi.fn().mockResolvedValue({}),
  stop: vi.fn().mockResolvedValue(undefined),
  quit: vi.fn(),
  beforeQuit: vi.fn(),
}))
vi.mock('electron', () => ({
  app: { quit: mocks.quit, once: mocks.beforeQuit },
  Tray: class extends EventEmitter {
    setContextMenu = mocks.menu
    setToolTip = vi.fn()
    destroy = mocks.destroy
  },
  Menu: { buildFromTemplate: (items: unknown) => items },
  nativeImage: { createFromDataURL: () => ({ resize: () => ({}) }) },
}))
vi.mock('../../../../src/main/log', () => ({ log: { error: vi.fn() } }))
vi.mock('../../../../src/main/hub/server/register', () => ({
  getHub: () => ({
    status: () => ({ running: mocks.running, addresses: ['http://192.168.1.2:8765'] }),
    settings: { keepRunningInTray: mocks.keep },
  }),
  onHubChanged: () => () => {},
  updateHubSettings: mocks.update,
  stopHub: mocks.stop,
}))

it('keeps a running hub alive, offers translated tray actions, and stops on quit', async () => {
  const { shouldKeepRunningWithoutWindows, onMainWindowCreated, shutdownHub } =
    await import('../../../../src/main/hub/server/lifecycle')
  expect(shouldKeepRunningWithoutWindows()).toBe(true)
  mocks.keep = false
  expect(shouldKeepRunningWithoutWindows()).toBe(false)
  mocks.keep = true
  mocks.running = false
  expect(shouldKeepRunningWithoutWindows()).toBe(false)
  mocks.running = true
  const recreate = vi.fn()
  onMainWindowCreated({} as BrowserWindow, recreate)
  const menu = mocks.menu.mock.calls[0][0] as { label?: string; click?: () => void }[]
  expect(menu.map((m) => m.label).filter(Boolean)).toEqual([
    'GitHub+ 열기',
    '허브: 실행 중 (http://192.168.1.2:8765)',
    '허브 끄기',
    '종료',
  ])
  menu[0].click!()
  expect(recreate).toHaveBeenCalledOnce()
  menu[2].click!()
  expect(mocks.update).toHaveBeenCalledWith({ enabled: false })
  const preventDefault = vi.fn()
  mocks.beforeQuit.mock.calls[0][1]({ preventDefault })
  await vi.waitFor(() => expect(mocks.quit).toHaveBeenCalledOnce())
  expect(preventDefault).toHaveBeenCalledOnce()
  await shutdownHub()
  expect(mocks.destroy).toHaveBeenCalledOnce()
  expect(mocks.stop).toHaveBeenCalled()
})
