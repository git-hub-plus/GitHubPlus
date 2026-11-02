import { BrowserWindow } from 'electron'
import * as ipcMain from './ipc-main'
import * as ipcWebContents from './ipc-webcontents'
import { getLanguage, isLanguage } from '../lib/i18n'
import { saveMenuLanguage } from './menu/language-settings'
import { rebuildLocalizedMenu } from './menu/build-default-menu'

/** Register language IPC after the main window and initial menu exist. */
export function registerI18nIPC(sendAppMenu: () => void): void {
  let pending = Promise.resolve()
  ipcMain.handle('get-app-language', async () => getLanguage())
  ipcMain.handle('set-app-language', (event, language) => {
    if (!isLanguage(language)) {
      return Promise.reject(new Error('Unsupported app language'))
    }
    if (
      !BrowserWindow.getAllWindows().some(w => w.webContents === event.sender)
    ) {
      return Promise.reject(new Error('Unknown language settings sender'))
    }
    const update = pending.then(async () => {
      await saveMenuLanguage(language)
      rebuildLocalizedMenu()
      sendAppMenu()
      for (const window of BrowserWindow.getAllWindows()) {
        ipcWebContents.send(
          window.webContents,
          'app-language-changed',
          language
        )
      }
      return language
    })
    pending = update.then(
      () => undefined,
      () => undefined
    )
    return update
  })
}
