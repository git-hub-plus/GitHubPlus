import { join } from 'node:path'
import { app, BrowserWindow, shell } from 'electron'
import { registerAllHandlers } from './register-all'
import { trustWebContents } from './ipc'
import { log } from './log'
import { buildMenu } from './menu'
import { loadRepositories } from './store/repositories'
import { loadSettings, onSettingsChanged } from './store/settings'
import { stopWatchingRepository } from './watch'
import {
  onMainWindowCreated,
  shouldKeepRunningWithoutWindows,
  shutdownHub,
} from './hub/server/lifecycle'

// Keep the user data folder separate from the official GitHub Desktop and from
// development runs of GitHub+.
app.setName('GitHub+')
if (!app.isPackaged) {
  app.setPath('userData', join(app.getPath('appData'), 'GitHub+-dev'))
}

if (!app.requestSingleInstanceLock()) {
  app.quit()
}

let mainWindow: BrowserWindow | undefined

function createWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 900,
    minHeight: 600,
    show: false,
    title: 'GitHub+',
    autoHideMenuBar: false,
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
    },
  })
  trustWebContents(window.webContents.id)

  window.once('ready-to-show', () => window.show())

  // Never navigate the app window away; open http(s) links in the browser.
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) {
      void shell.openExternal(url)
    }
    return { action: 'deny' }
  })
  window.webContents.on('will-navigate', (event, url) => {
    if (url !== window.webContents.getURL()) {
      event.preventDefault()
    }
  })

  const devServerUrl = process.env['ELECTRON_RENDERER_URL']
  if (!app.isPackaged && devServerUrl) {
    void window.loadURL(devServerUrl)
  } else {
    void window.loadFile(join(__dirname, '../renderer/index.html'))
  }
  return window
}

app.on('second-instance', () => {
  if (mainWindow) {
    if (mainWindow.isMinimized()) {
      mainWindow.restore()
    }
    mainWindow.focus()
  }
})

app.on('will-quit', () => {
  stopWatchingRepository()
  void shutdownHub()
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin' && !shouldKeepRunningWithoutWindows()) {
    app.quit()
  }
})

void app.whenReady().then(async () => {
  await loadSettings()
  await loadRepositories()
  registerAllHandlers()
  buildMenu()
  onSettingsChanged(() => buildMenu())
  mainWindow = createWindow()
  onMainWindowCreated(mainWindow, () => {
    if (!mainWindow || mainWindow.isDestroyed()) mainWindow = createWindow()
    mainWindow.show()
    mainWindow.focus()
  })
  log.info(`GitHub+ ${app.getVersion()} started`)
})
