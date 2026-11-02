import { mkdir, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { app, BrowserWindow, dialog } from 'electron'
import { HandlerError } from '@shared/errors'
import { getGitVersion, initRepository } from '../git/inspect'
import { broadcast, handle } from '../ipc'
import {
  addRepository,
  listRepositories,
  onRepositoriesChanged,
  removeRepository,
  updateRepository,
} from '../store/repositories'
import { getSettings, onSettingsChanged, updateSettings } from '../store/settings'
import { watchRepository } from '../watch'

/** Rejects names Windows cannot use as a folder name. */
function isValidRepositoryName(name: string): boolean {
  return (
    name.length > 0 &&
    !/[<>:"/\\|?*]/.test(name) &&
    [...name].every((ch) => ch.charCodeAt(0) >= 0x20)
  )
}

/** Registers app, settings, dialog and repository-list handlers. */
export function registerAppHandlers(): void {
  handle('app:getInfo', async () => ({
    name: app.getName(),
    version: app.getVersion(),
    platform: process.platform,
    gitVersion: await getGitVersion(),
  }))

  handle('settings:get', () => getSettings())
  handle('settings:update', (_event, patch) => updateSettings(patch))
  onSettingsChanged((settings) => broadcast('settings:changed', settings))

  handle('dialog:pickDirectory', async (event, options) => {
    const window = BrowserWindow.fromWebContents(event.sender)
    const pickOptions: Electron.OpenDialogOptions = {
      title: options?.title,
      defaultPath: options?.defaultPath,
      properties: ['openDirectory', 'createDirectory'],
    }
    const result = window
      ? await dialog.showOpenDialog(window, pickOptions)
      : await dialog.showOpenDialog(pickOptions)
    return result.canceled ? null : (result.filePaths[0] ?? null)
  })

  handle('repos:list', () => listRepositories())
  handle('repos:add', (_event, path) => addRepository(path))
  handle('repos:remove', (_event, id) => removeRepository(id))
  handle('repos:update', (_event, id, patch) => updateRepository(id, patch))
  handle('repos:open', async (_event, id) => {
    const repo = await updateRepository(id, { lastOpenedAt: Date.now() })
    await watchRepository(id)
    return repo
  })
  handle('repos:create', async (_event, input) => {
    const name = input.name.trim()
    if (!isValidRepositoryName(name)) {
      throw new HandlerError('invalid-argument', `Invalid repository name: ${input.name}`)
    }
    const path = join(input.parentDirectory, name)
    await mkdir(path, { recursive: true })
    await initRepository(path, input.initialBranch || 'main')
    if (input.addReadme) {
      await writeFile(join(path, 'README.md'), `# ${name}\n`, 'utf8')
    }
    return addRepository(path)
  })
  onRepositoriesChanged((list) => broadcast('repos:changed', list))
}
