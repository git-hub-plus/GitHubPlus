import assert from 'node:assert/strict'
import { afterEach, before, beforeEach, describe, it, mock } from 'node:test'
import { Language, setLanguage } from '../../../src/lib/i18n'

type GetLanguageHandler = () => Promise<Language>
type SetLanguageHandler = (
  event: { readonly sender: object },
  language: Language
) => Promise<Language>

const handle = mock.fn((_channel: string, _handler: unknown) => {})
const sender = {}
const otherSender = {}
const send = mock.fn((..._args: unknown[]) => {})
const rebuild = mock.fn(() => {})
const sendAppMenu = mock.fn(() => {})
let failSave = false
const save = mock.fn(async (language: Language) => {
  if (failSave) {
    throw new Error('Disk unavailable')
  }
  setLanguage(language)
  return language
})

// Replace the renderer-only Electron mock installed by the global test setup.
mock.restoreAll()
mock.module('electron', {
  namedExports: {
    BrowserWindow: {
      getAllWindows: () => [
        { webContents: sender },
        { webContents: otherSender },
      ],
    },
  },
})
mock.module('../../../src/main-process/ipc-main', {
  namedExports: { handle },
})
mock.module('../../../src/main-process/ipc-webcontents', {
  namedExports: { send },
})
mock.module('../../../src/main-process/menu/language-settings', {
  namedExports: { saveMenuLanguage: save },
})
mock.module('../../../src/main-process/menu/build-default-menu', {
  namedExports: { rebuildLocalizedMenu: rebuild },
})

describe('language IPC', () => {
  let get: GetLanguageHandler
  let set: SetLanguageHandler
  before(async () => {
    const { registerI18nIPC } = await import(
      '../../../src/main-process/i18n-ipc'
    )
    registerI18nIPC(sendAppMenu)
    get = handle.mock.calls.find(
      call => call.arguments[0] === 'get-app-language'
    )!.arguments[1] as GetLanguageHandler
    set = handle.mock.calls.find(
      call => call.arguments[0] === 'set-app-language'
    )!.arguments[1] as SetLanguageHandler
  })
  beforeEach(() => {
    setLanguage('ko')
    failSave = false
    for (const fn of [save, send, rebuild, sendAppMenu]) {
      fn.mock.resetCalls()
    }
  })
  afterEach(() => setLanguage('ko'))

  it('reads the current language and broadcasts successful changes to every window', async () => {
    assert.equal(await get(), 'ko')
    assert.equal(await set({ sender }, 'en'), 'en')
    assert.equal(await get(), 'en')
    assert.equal(save.mock.callCount(), 1)
    assert.equal(rebuild.mock.callCount(), 1)
    assert.equal(sendAppMenu.mock.callCount(), 1)
    assert.deepEqual(
      send.mock.calls.map(call => call.arguments),
      [
        [sender, 'app-language-changed', 'en'],
        [otherSender, 'app-language-changed', 'en'],
      ]
    )
  })

  it('serializes rapid changes in request order', async () => {
    assert.deepEqual(
      await Promise.all([set({ sender }, 'en'), set({ sender }, 'ko')]),
      ['en', 'ko']
    )
    assert.equal(await get(), 'ko')
    assert.deepEqual(
      save.mock.calls.map(call => call.arguments[0]),
      ['en', 'ko']
    )
  })

  it('does not broadcast failed saves and accepts a later retry', async () => {
    failSave = true
    await assert.rejects(set({ sender }, 'en'), /Disk unavailable/)
    assert.equal(await get(), 'ko')
    assert.equal(rebuild.mock.callCount(), 0)
    assert.equal(send.mock.callCount(), 0)
    failSave = false
    assert.equal(await set({ sender }, 'en'), 'en')
  })

  it('rejects senders outside app windows', async () => {
    await assert.rejects(
      set({ sender: {} }, 'en'),
      /Unknown language settings sender/
    )
    assert.equal(save.mock.callCount(), 0)
  })
})
