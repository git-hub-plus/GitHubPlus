import { app, BrowserWindow, Menu, shell, type MenuItemConstructorOptions } from 'electron'
import type { MenuCommand } from '@shared/models/app'
import { t } from '@shared/i18n'
import { broadcast } from './ipc'

const issuesUrl = 'https://github.com/git-hub-plus/GitHubPlus/issues'

function command(id: MenuCommand) {
  return () => broadcast('menu:command', id)
}

/** Builds the native menu from the current language; call again after a language change. */
export function buildMenu(): void {
  const isDev = !app.isPackaged
  const template: MenuItemConstructorOptions[] = [
    {
      label: t('menu.file'),
      submenu: [
        {
          label: t('menu.createRepository'),
          accelerator: 'CmdOrCtrl+N',
          click: command('create-repository'),
        },
        {
          label: t('menu.addRepository'),
          accelerator: 'CmdOrCtrl+O',
          click: command('add-repository'),
        },
        {
          label: t('menu.cloneRepository'),
          accelerator: 'CmdOrCtrl+Shift+O',
          click: command('clone-repository'),
        },
        { type: 'separator' },
        {
          label: t('menu.preferences'),
          accelerator: 'CmdOrCtrl+,',
          click: command('open-preferences'),
        },
        { type: 'separator' },
        { label: t('menu.quit'), role: 'quit' },
      ],
    },
    {
      label: t('menu.edit'),
      submenu: [
        { label: t('menu.undo'), role: 'undo' },
        { label: t('menu.redo'), role: 'redo' },
        { type: 'separator' },
        { label: t('menu.cut'), role: 'cut' },
        { label: t('menu.copy'), role: 'copy' },
        { label: t('menu.paste'), role: 'paste' },
        { label: t('menu.selectAll'), role: 'selectAll' },
      ],
    },
    {
      label: t('menu.view'),
      submenu: [
        {
          label: t('menu.showChanges'),
          accelerator: 'CmdOrCtrl+1',
          click: command('show-changes'),
        },
        {
          label: t('menu.showHistory'),
          accelerator: 'CmdOrCtrl+2',
          click: command('show-history'),
        },
        {
          label: t('menu.commandPalette'),
          accelerator: 'CmdOrCtrl+K',
          click: command('command-palette'),
        },
        { type: 'separator' },
        { label: t('menu.toggleFullScreen'), role: 'togglefullscreen' },
        ...(isDev
          ? ([
              { label: t('menu.reload'), role: 'reload' },
              { label: t('menu.toggleDevTools'), role: 'toggleDevTools' },
            ] satisfies MenuItemConstructorOptions[])
          : []),
      ],
    },
    {
      label: t('menu.repository'),
      submenu: [
        { label: t('menu.fetch'), accelerator: 'CmdOrCtrl+Shift+T', click: command('fetch') },
        { label: t('menu.pull'), accelerator: 'CmdOrCtrl+Shift+P', click: command('pull') },
        { label: t('menu.push'), accelerator: 'CmdOrCtrl+P', click: command('push') },
      ],
    },
    {
      label: t('menu.branch'),
      submenu: [
        {
          label: t('menu.newBranch'),
          accelerator: 'CmdOrCtrl+Shift+N',
          click: command('new-branch'),
        },
      ],
    },
    {
      label: t('menu.help'),
      submenu: [
        { label: t('menu.reportIssue'), click: () => void shell.openExternal(issuesUrl) },
        { label: t('menu.about'), click: command('about') },
      ],
    },
  ]
  Menu.setApplicationMenu(Menu.buildFromTemplate(template))
  for (const window of BrowserWindow.getAllWindows()) {
    window.setMenuBarVisibility(true)
  }
}
