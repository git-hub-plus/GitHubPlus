import type { BrowserWindow } from 'electron'

/**
 * App lifecycle hooks for the hub host. Owner: H1 (wave A).
 * index.ts calls these; H1 implements tray and keep-running behaviour here.
 */
export function shouldKeepRunningWithoutWindows(): boolean {
  return false
}

/** Called once the main window exists (e.g. to create the tray icon). */
export function onMainWindowCreated(_window: BrowserWindow, _recreate: () => void): void {}

/** Called before quitting (stop the server, close sockets). */
export async function shutdownHub(): Promise<void> {}
