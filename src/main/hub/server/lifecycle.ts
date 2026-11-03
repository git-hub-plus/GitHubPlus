import { app, Menu, nativeImage, Tray, type BrowserWindow } from 'electron'
import { onLanguageChanged, t } from '@shared/i18n'
import { log } from '../../log'
import { getHub, onHubChanged, stopHub, updateHubSettings } from './register'

let tray: Tray | undefined
let unsubscribe: (() => void)[] = []

/**
 * App lifecycle hooks for the hub host. Owner: H1 (wave A).
 * index.ts calls these; H1 implements tray and keep-running behaviour here.
 */
export function shouldKeepRunningWithoutWindows(): boolean {
  const hub = getHub()
  return !!hub?.status().running && hub.settings.keepRunningInTray
}

/** Called once the main window exists (e.g. to create the tray icon). */
export function onMainWindowCreated(_window: BrowserWindow, recreate: () => void): void {
  if (tray) return
  app.once('before-quit', (event) => {
    event.preventDefault()
    void shutdownHub()
      .catch((error: unknown) => log.error('Hub shutdown failed', error))
      .finally(() => app.quit())
  })
  // Small embedded PNG avoids runtime assets and native dependencies.
  tray = new Tray(
    nativeImage
      .createFromDataURL(
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAJklEQVR4nGNgGDRAIenIfxgGAWQ+NrFRA4gwABsYYl4YiQYMGAAAwG925E76YlUAAAAASUVORK5CYII='
      )
      .resize({ width: 16, height: 16 })
  )
  const refresh = (): void => {
    const hub = getHub()
    const running = hub?.status().running ?? false
    tray?.setToolTip(t('hubTray.title'))
    tray?.setContextMenu(
      Menu.buildFromTemplate([
        { label: t('hubTray.open'), click: recreate },
        {
          label: running
            ? t('hubTray.running', {
                address: hub?.status().addresses[0] ?? `http://localhost:${hub?.status().port}`,
              })
            : t('hubTray.stopped'),
          enabled: false,
        },
        {
          label: t(running ? 'hubTray.disable' : 'hubTray.enable'),
          click: () => {
            void updateHubSettings({ enabled: !running }).catch((error: unknown) =>
              log.error('Hub toggle failed', error)
            )
          },
        },
        { type: 'separator' },
        { label: t('hubTray.quit'), click: () => app.quit() },
      ])
    )
  }
  tray.on('double-click', recreate)
  unsubscribe = [onHubChanged(refresh), onLanguageChanged(refresh)]
  refresh()
}

/** Called before quitting (stop the server, close sockets). */
export async function shutdownHub(): Promise<void> {
  for (const dispose of unsubscribe) dispose()
  unsubscribe = []
  tray?.destroy()
  tray = undefined
  await stopHub()
}
