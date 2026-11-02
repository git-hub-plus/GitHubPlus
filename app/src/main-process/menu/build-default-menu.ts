import { t as translate, TranslationKey } from '../../lib/i18n'
import { Menu, shell, app, BrowserWindow } from 'electron'
import { ensureItemIds } from './ensure-item-ids'
import { MenuEvent } from './menu-event'
import { truncateWithEllipsis } from '../../lib/truncate-with-ellipsis'
import { getLogDirectoryPath } from '../../lib/logging/get-log-path'
import { UNSAFE_openDirectory } from '../shell'
import {
  enableCopilotAppHandoff,
  enableWorktreeSupport,
} from '../../lib/feature-flag'
import { MenuLabelsEvent } from '../../models/menu-labels'
import * as ipcWebContents from '../ipc-webcontents'
import { mkdir } from 'fs/promises'
import { buildTestMenu } from './build-test-menu'
import { initializeMenuLanguageSync } from './language-settings'
import { getAllMenuItems } from './get-all-menu-items'

let latestLabels: MenuLabelsEvent | undefined

function t(
  key: TranslationKey,
  params?: Readonly<Record<string, string | number>>
) {
  const label = translate(key)
  const platformLabel = __DARWIN__
    ? label.replace(/\(&.\)/g, '').replace(/&(.)/g, '$1')
    : label
  return platformLabel.replace(
    /\{(\w+)\}/g,
    (placeholder, name: string) => params?.[name]?.toString() ?? placeholder
  )
}

enum ZoomDirection {
  Reset,
  In,
  Out,
}

export const separator: Electron.MenuItemConstructorOptions = {
  type: 'separator',
}

export function buildDefaultMenu(params: MenuLabelsEvent): Electron.Menu {
  initializeMenuLanguageSync()
  latestLabels = params
  return Menu.buildFromTemplate(buildDefaultMenuTemplate(params))
}

/** Rebuild translated labels while preserving current menu item state. */
export function rebuildLocalizedMenu(): void {
  if (latestLabels === undefined) {
    return
  }
  const currentMenu = Menu.getApplicationMenu()
  const states = new Map(
    currentMenu === null
      ? []
      : Array.from(
          getAllMenuItems(currentMenu),
          item => [item.id, item] as const
        )
  )
  const menu = buildDefaultMenu(latestLabels)
  for (const item of getAllMenuItems(menu)) {
    const previous = states.get(item.id)
    if (previous !== undefined) {
      item.enabled = previous.enabled
      item.visible = previous.visible
      item.checked = previous.checked
    }
  }
  Menu.setApplicationMenu(menu)
}

export function buildDefaultMenuTemplate({
  selectedExternalEditor,
  selectedShell,
  askForConfirmationOnForcePush,
  askForConfirmationOnRepositoryRemoval,
  hasCurrentPullRequest = false,
  contributionTargetDefaultBranch = t('menu.defaultBranch'),
  isForcePushForCurrentRepository = false,
  isStashedChangesVisible = false,
  askForConfirmationWhenStashingAllChanges = true,
  isChangesFilterVisible = true,
}: MenuLabelsEvent): Electron.MenuItemConstructorOptions[] {
  const createPullRequestLabel = __DARWIN__
    ? t('menu.labels.createPullRequest')
    : t('menu.labels.createPullRequestAccessKey')
  const showPullRequestLabel = __DARWIN__
    ? t('menu.labels.viewPullRequestOnGithub')
    : t('menu.labels.viewPullRequestOnGithubAccessKey')
  const confirmRepositoryRemovalLabel = __DARWIN__
    ? t('menu.labels.remove')
    : t('menu.labels.removeAccessKey')
  const repositoryRemovalLabel = __DARWIN__
    ? t('menu.labels.remove2')
    : t('menu.labels.removeAccessKey2')
  const confirmStashAllChangesLabel = __DARWIN__
    ? t('menu.labels.stashAllChanges')
    : t('menu.labels.stashAllChangesAccessKey')
  const stashAllChangesLabel = __DARWIN__
    ? t('menu.labels.stashAllChanges2')
    : t('menu.labels.stashAllChangesAccessKey2')

  contributionTargetDefaultBranch = truncateWithEllipsis(
    contributionTargetDefaultBranch,
    25
  )

  const removeRepoLabel = askForConfirmationOnRepositoryRemoval
    ? confirmRepositoryRemovalLabel
    : repositoryRemovalLabel

  const pullRequestLabel = hasCurrentPullRequest
    ? showPullRequestLabel
    : createPullRequestLabel

  const template = new Array<Electron.MenuItemConstructorOptions>()

  if (__DARWIN__) {
    template.push({
      label: t('menu.labels.githubplus'),
      submenu: [
        {
          label: t('menu.labels.aboutGithubplus'),
          click: emit('show-about'),
          id: 'about',
        },
        separator,
        {
          label: t('menu.labels.settings'),
          id: 'preferences',
          accelerator: 'CmdOrCtrl+,',
          click: emit('show-preferences'),
        },
        separator,
        {
          label: t('menu.labels.installCommandLineTool'),
          id: 'install-cli',
          click: emit('install-darwin-cli'),
        },
        separator,
        {
          role: 'services',
          label: t('menu.roles.services'),
          submenu: [],
        },
        separator,
        { role: 'hide', label: t('menu.roles.hide') },
        { role: 'hideOthers', label: t('menu.roles.hideOthers') },
        { role: 'unhide', label: t('menu.roles.unhide') },
        separator,
        { role: 'quit', label: t('menu.roles.quit') },
      ],
    })
  }

  const fileMenu: Electron.MenuItemConstructorOptions = {
    label: __DARWIN__ ? t('menu.labels.file') : t('menu.labels.fileAccessKey'),
    submenu: [
      {
        label: __DARWIN__
          ? t('menu.labels.newRepository')
          : t('menu.labels.newRepositoryAccessKey'),
        id: 'new-repository',
        click: emit('create-repository'),
        accelerator: 'CmdOrCtrl+N',
      },
      separator,
      {
        label: __DARWIN__
          ? t('menu.labels.addLocalRepository')
          : t('menu.labels.addLocalRepositoryAccessKey'),
        id: 'add-local-repository',
        accelerator: 'CmdOrCtrl+O',
        click: emit('add-local-repository'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.cloneRepository')
          : t('menu.labels.cloneRepositoryAccessKey'),
        id: 'clone-repository',
        accelerator: 'CmdOrCtrl+Shift+O',
        click: emit('clone-repository'),
      },
    ],
  }

  if (!__DARWIN__) {
    const fileItems = fileMenu.submenu as Electron.MenuItemConstructorOptions[]
    const exitAccelerator = __WIN32__ ? 'Alt+F4' : 'CmdOrCtrl+Q'

    fileItems.push(
      separator,
      {
        label: t('menu.labels.optionsAccessKey'),
        id: 'preferences',
        accelerator: 'CmdOrCtrl+,',
        click: emit('show-preferences'),
      },
      separator,
      {
        role: 'quit',
        label: t('menu.labels.exitAccessKey'),
        accelerator: exitAccelerator,
      }
    )
  }

  template.push(fileMenu)

  template.push({
    label: __DARWIN__ ? t('menu.labels.edit') : t('menu.labels.editAccessKey'),
    submenu: [
      {
        role: 'undo',
        label: __DARWIN__
          ? t('menu.labels.undo')
          : t('menu.labels.undoAccessKey'),
      },
      {
        role: 'redo',
        label: __DARWIN__
          ? t('menu.labels.redo')
          : t('menu.labels.redoAccessKey'),
      },
      separator,
      {
        role: 'cut',
        label: __DARWIN__
          ? t('menu.labels.cut')
          : t('menu.labels.cutAccessKey'),
      },
      {
        role: 'copy',
        label: __DARWIN__
          ? t('menu.labels.copy')
          : t('menu.labels.copyAccessKey'),
      },
      {
        role: 'paste',
        label: __DARWIN__
          ? t('menu.labels.paste')
          : t('menu.labels.pasteAccessKey'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.selectAll')
          : t('menu.labels.selectAllAccessKey'),
        accelerator: 'CmdOrCtrl+A',
        click: emit('select-all'),
      },
      separator,
      {
        id: 'find',
        label: __DARWIN__
          ? t('menu.labels.find')
          : t('menu.labels.findAccessKey'),
        accelerator: 'CmdOrCtrl+F',
        click: emit('find-text'),
      },
    ],
  })

  template.push({
    label: __DARWIN__ ? t('menu.labels.view') : t('menu.labels.viewAccessKey'),
    submenu: [
      {
        label: __DARWIN__
          ? t('menu.labels.showChanges')
          : t('menu.labels.changesAccessKey'),
        id: 'show-changes',
        accelerator: 'CmdOrCtrl+1',
        click: emit('show-changes'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.showHistory')
          : t('menu.labels.historyAccessKey'),
        id: 'show-history',
        accelerator: 'CmdOrCtrl+2',
        click: emit('show-history'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.showRepositoryList')
          : t('menu.labels.repositoryListAccessKey'),
        id: 'show-repository-list',
        accelerator: 'CmdOrCtrl+T',
        click: emit('choose-repository'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.showBranchesList')
          : t('menu.labels.branchesListAccessKey'),
        id: 'show-branches-list',
        accelerator: 'CmdOrCtrl+B',
        click: emit('show-branches'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.showWorktreesList')
          : t('menu.labels.worktreesListAccessKey'),
        id: 'show-worktrees-list',
        accelerator: 'CmdOrCtrl+Alt+W',
        click: emit('show-worktrees'),
        visible: enableWorktreeSupport(),
      },
      separator,
      {
        label: __DARWIN__
          ? t('menu.labels.goToSummary')
          : t('menu.labels.goToSummaryAccessKey'),
        id: 'go-to-commit-message',
        accelerator: 'CmdOrCtrl+G',
        click: emit('go-to-commit-message'),
      },
      {
        label: getStashedChangesLabel(isStashedChangesVisible),
        id: 'toggle-stashed-changes',
        accelerator: 'Ctrl+H',
        click: isStashedChangesVisible
          ? emit('hide-stashed-changes')
          : emit('show-stashed-changes'),
      },
      {
        label: t(
          isChangesFilterVisible
            ? 'menu.hideChangesFilter'
            : 'menu.showChangesFilter'
        ),
        id: 'toggle-changes-filter',
        accelerator: 'CmdOrCtrl+L',
        click: emit('toggle-changes-filter'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.toggleFullScreen')
          : t('menu.labels.toggleFullScreenAccessKey'),
        role: 'togglefullscreen',
      },
      separator,
      {
        label: __DARWIN__
          ? t('menu.labels.resetZoom')
          : t('menu.labels.resetZoom2'),
        accelerator: 'CmdOrCtrl+0',
        click: zoom(ZoomDirection.Reset),
      },
      {
        label: __DARWIN__ ? t('menu.labels.zoomIn') : t('menu.labels.zoomIn2'),
        accelerator: 'CmdOrCtrl+=',
        click: zoom(ZoomDirection.In),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.zoomOut')
          : t('menu.labels.zoomOut2'),
        accelerator: 'CmdOrCtrl+-',
        click: zoom(ZoomDirection.Out),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.expandActiveResizable')
          : t('menu.labels.expandActiveResizable2'),
        id: 'increase-active-resizable-width',
        accelerator: 'CmdOrCtrl+9',
        click: emit('increase-active-resizable-width'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.contractActiveResizable')
          : t('menu.labels.contractActiveResizable2'),
        id: 'decrease-active-resizable-width',
        accelerator: 'CmdOrCtrl+8',
        click: emit('decrease-active-resizable-width'),
      },
      separator,
      {
        label: t('menu.labels.reloadAccessKey'),
        id: 'reload-window',
        // Ctrl+Alt is interpreted as AltGr on international keyboards and this
        // can clash with other shortcuts. We should always use Ctrl+Shift for
        // chorded shortcuts, but this menu item is not a user-facing feature
        // so we are going to keep this one around.
        accelerator: 'CmdOrCtrl+Alt+R',
        click(item: any, focusedWindow: Electron.BaseWindow | undefined) {
          if (focusedWindow instanceof BrowserWindow) {
            focusedWindow.reload()
          }
        },
        visible: __RELEASE_CHANNEL__ === 'development',
      },
      {
        id: 'show-devtools',
        label: __DARWIN__
          ? t('menu.labels.toggleDeveloperTools')
          : t('menu.labels.toggleDeveloperToolsAccessKey'),
        accelerator: (() => {
          return __DARWIN__ ? 'Alt+Command+I' : 'Ctrl+Shift+I'
        })(),
        click(item: any, focusedWindow: Electron.BaseWindow | undefined) {
          if (focusedWindow instanceof BrowserWindow) {
            focusedWindow.webContents.toggleDevTools()
          }
        },
      },
    ],
  })

  const pushLabel = getPushLabel(
    isForcePushForCurrentRepository,
    askForConfirmationOnForcePush
  )

  const pushEventType = isForcePushForCurrentRepository ? 'force-push' : 'push'

  template.push({
    label: __DARWIN__
      ? t('menu.labels.repository')
      : t('menu.labels.repositoryAccessKey'),
    id: 'repository',
    submenu: [
      {
        id: 'push',
        label: pushLabel,
        accelerator: 'CmdOrCtrl+P',
        click: emit(pushEventType),
      },
      {
        id: 'pull',
        label: __DARWIN__
          ? t('menu.labels.pull')
          : t('menu.labels.pullAccessKey'),
        accelerator: 'CmdOrCtrl+Shift+P',
        click: emit('pull'),
      },
      {
        id: 'fetch',
        label: __DARWIN__
          ? t('menu.labels.fetch')
          : t('menu.labels.fetchAccessKey'),
        accelerator: 'CmdOrCtrl+Shift+T',
        click: emit('fetch'),
      },
      {
        label: removeRepoLabel,
        id: 'remove-repository',
        accelerator: 'CmdOrCtrl+Backspace',
        click: emit('remove-repository'),
      },
      separator,
      {
        id: 'view-repository-on-github',
        label: __DARWIN__
          ? t('menu.labels.viewOnGithub')
          : t('menu.labels.viewOnGithubAccessKey'),
        accelerator: 'CmdOrCtrl+Shift+G',
        click: emit('view-repository-on-github'),
      },
      {
        label: t('menu.openInShell', {
          name: selectedShell ?? t('menu.shell'),
        }),
        id: 'open-in-shell',
        accelerator: 'Ctrl+`',
        click: emit('open-in-shell'),
      },
      {
        label: __DARWIN__
          ? t('menu.labels.showInFinder')
          : __WIN32__
          ? t('menu.labels.showInExplorerAccessKey')
          : t('menu.labels.showInYourFileManager'),
        id: 'open-working-directory',
        accelerator: 'CmdOrCtrl+Shift+F',
        click: emit('open-working-directory'),
      },
      {
        label: t('menu.openInEditor', {
          name: selectedExternalEditor ?? t('menu.externalEditor'),
        }),
        id: 'open-external-editor',
        accelerator: 'CmdOrCtrl+Shift+A',
        click: emit('open-external-editor'),
      },
      ...(enableCopilotAppHandoff()
        ? [
            {
              label: __DARWIN__
                ? t('menu.labels.openInGithubCopilot')
                : t('menu.labels.openInGithubCopilotAccessKey'),
              id: 'open-in-copilot-app',
              accelerator: 'CmdOrCtrl+Shift+J',
              click: emit('open-in-copilot-app'),
            },
          ]
        : []),
      {
        label: __DARWIN__
          ? t('menu.labels.openWith')
          : t('menu.labels.openWithAccessKey'),
        id: 'open-with-external-editor',
        accelerator: 'CmdOrCtrl+Shift+Alt+A',
        click: emit('open-with-external-editor'),
      },
      separator,
      {
        id: 'create-issue-in-repository-on-github',
        label: __DARWIN__
          ? t('menu.labels.createIssueOnGithub')
          : t('menu.labels.createIssueOnGithubAccessKey'),
        accelerator: 'CmdOrCtrl+I',
        click: emit('create-issue-in-repository-on-github'),
      },
      separator,
      {
        id: 'create-worktree',
        label: __DARWIN__
          ? t('menu.labels.newWorktree')
          : t('menu.labels.newWorktreeAccessKey'),
        click: emit('create-worktree'),
        accelerator: 'CmdOrCtrl+Shift+W',
        visible: enableWorktreeSupport(),
      },
      ...(enableWorktreeSupport() ? [separator] : []),
      {
        label: __DARWIN__
          ? t('menu.labels.repositorySettings')
          : t('menu.labels.repositorySettingsAccessKey'),
        id: 'show-repository-settings',
        click: emit('show-repository-settings'),
      },
    ],
  })

  const branchSubmenu = [
    {
      label: __DARWIN__
        ? t('menu.labels.newBranch')
        : t('menu.labels.newBranchAccessKey'),
      id: 'create-branch',
      accelerator: 'CmdOrCtrl+Shift+N',
      click: emit('create-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.rename')
        : t('menu.labels.renameAccessKey'),
      id: 'rename-branch',
      accelerator: 'CmdOrCtrl+Shift+R',
      click: emit('rename-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.delete')
        : t('menu.labels.deleteAccessKey'),
      id: 'delete-branch',
      accelerator: 'CmdOrCtrl+Shift+D',
      click: emit('delete-branch'),
    },
    separator,
    {
      label: __DARWIN__
        ? t('menu.labels.discardAllChanges')
        : t('menu.labels.discardAllChanges2'),
      id: 'discard-all-changes',
      accelerator: 'CmdOrCtrl+Shift+Backspace',
      click: emit('discard-all-changes'),
    },
    {
      label: askForConfirmationWhenStashingAllChanges
        ? confirmStashAllChangesLabel
        : stashAllChangesLabel,
      id: 'stash-all-changes',
      accelerator: 'CmdOrCtrl+Shift+S',
      click: emit('stash-all-changes'),
    },
    separator,
    {
      label: t('menu.updateFromBranch', {
        name: contributionTargetDefaultBranch,
      }),
      id: 'update-branch-with-contribution-target-branch',
      accelerator: 'CmdOrCtrl+Shift+U',
      click: emit('update-branch-with-contribution-target-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.compareToBranch')
        : t('menu.labels.compareToBranchAccessKey'),
      id: 'compare-to-branch',
      accelerator: 'CmdOrCtrl+Shift+B',
      click: emit('compare-to-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.mergeIntoCurrentBranch')
        : t('menu.labels.mergeIntoCurrentBranchAccessKey'),
      id: 'merge-branch',
      accelerator: 'CmdOrCtrl+Shift+M',
      click: emit('merge-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.squashAndMergeIntoCurrentBranch')
        : t('menu.labels.squashAndMergeIntoCurrentBranchAccessKey'),
      id: 'squash-and-merge-branch',
      accelerator: 'CmdOrCtrl+Shift+H',
      click: emit('squash-and-merge-branch'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.rebaseCurrentBranch')
        : t('menu.labels.rebaseCurrentBranchAccessKey'),
      id: 'rebase-branch',
      accelerator: 'CmdOrCtrl+Shift+E',
      click: emit('rebase-branch'),
    },
    separator,
    {
      label: __DARWIN__
        ? t('menu.labels.compareOnGithub')
        : t('menu.labels.compareOnGithubAccessKey'),
      id: 'compare-on-github',
      accelerator: 'CmdOrCtrl+Shift+C',
      click: emit('compare-on-github'),
    },
    {
      label: __DARWIN__
        ? t('menu.labels.viewBranchOnGithub')
        : t('menu.labels.viewBranchOnGithub2'),
      id: 'branch-on-github',
      accelerator: 'CmdOrCtrl+Alt+B',
      click: emit('branch-on-github'),
    },
  ]

  branchSubmenu.push({
    label: __DARWIN__
      ? t('menu.labels.previewPullRequest')
      : t('menu.labels.previewPullRequest2'),
    id: 'preview-pull-request',
    accelerator: 'CmdOrCtrl+Alt+P',
    click: emit('preview-pull-request'),
  })

  branchSubmenu.push({
    label: pullRequestLabel,
    id: 'create-pull-request',
    accelerator: 'CmdOrCtrl+R',
    click: emit('open-pull-request'),
  })

  template.push({
    label: __DARWIN__
      ? t('menu.labels.branch')
      : t('menu.labels.branchAccessKey'),
    id: 'branch',
    submenu: branchSubmenu,
  })

  if (__DARWIN__) {
    template.push({
      role: 'window',
      label: t('menu.roles.window'),
      submenu: [
        { role: 'minimize', label: t('menu.roles.minimize') },
        { role: 'zoom', label: t('menu.roles.zoom') },
        { role: 'close', label: t('menu.roles.close') },
        separator,
        { role: 'front', label: t('menu.roles.front') },
      ],
    })
  }

  const submitIssueItem: Electron.MenuItemConstructorOptions = {
    label: __DARWIN__
      ? t('menu.labels.reportIssue')
      : t('menu.labels.reportIssue2'),
    click() {
      shell
        .openExternal('https://github.com/Dev-Snow-flake/GitHubPlus/issues')
        .catch(err => log.error('Failed opening issue creation page', err))
    },
  }

  const contactSupportItem: Electron.MenuItemConstructorOptions = {
    label: __DARWIN__
      ? t('menu.labels.contactGithubSupport')
      : t('menu.labels.contactGithubSupportAccessKey'),
    click() {
      shell
        .openExternal(
          `https://github.com/contact?from_desktop_app=1&app_version=${app.getVersion()}`
        )
        .catch(err => log.error('Failed opening contact support page', err))
    },
  }

  const showUserGuides: Electron.MenuItemConstructorOptions = {
    label: t('menu.labels.showUserGuides'),
    click() {
      shell
        .openExternal('https://docs.github.com/en/desktop')
        .catch(err => log.error('Failed opening user guides page', err))
    },
  }

  const showKeyboardShortcuts: Electron.MenuItemConstructorOptions = {
    label: __DARWIN__
      ? t('menu.labels.showKeyboardShortcuts')
      : t('menu.labels.showKeyboardShortcuts2'),
    click() {
      shell
        .openExternal(
          'https://docs.github.com/en/desktop/installing-and-configuring-github-desktop/overview/keyboard-shortcuts'
        )
        .catch(err => log.error('Failed opening keyboard shortcuts page', err))
    },
  }

  const showLogsLabel = __DARWIN__
    ? t('menu.labels.showLogsInFinder')
    : __WIN32__
    ? t('menu.labels.showLogsInExplorerAccessKey')
    : t('menu.labels.showLogsInYourFileManagerAccessKey')

  const showLogsItem: Electron.MenuItemConstructorOptions = {
    label: showLogsLabel,
    click() {
      const logPath = getLogDirectoryPath()
      mkdir(logPath, { recursive: true })
        .then(() => UNSAFE_openDirectory(logPath))
        .catch(err => log.error('Failed opening logs directory', err))
    },
  }

  const helpItems = [
    submitIssueItem,
    contactSupportItem,
    showUserGuides,
    showKeyboardShortcuts,
    showLogsItem,
  ]

  helpItems.push(...buildTestMenu())

  if (__DARWIN__) {
    template.push({
      role: 'help',
      label: t('menu.roles.help'),
      submenu: helpItems,
    })
  } else {
    template.push({
      label: t('menu.labels.helpAccessKey'),
      submenu: [
        ...helpItems,
        separator,
        {
          label: t('menu.labels.aboutGithubplusAccessKey'),
          click: emit('show-about'),
          id: 'about',
        },
      ],
    })
  }

  ensureItemIds(template)

  return template
}

function getPushLabel(
  isForcePushForCurrentRepository: boolean,
  askForConfirmationOnForcePush: boolean
): string {
  if (!isForcePushForCurrentRepository) {
    return __DARWIN__ ? t('menu.labels.push') : t('menu.labels.pushAccessKey')
  }

  if (askForConfirmationOnForcePush) {
    return __DARWIN__
      ? t('menu.labels.forcePush')
      : t('menu.labels.forcePushAccessKey')
  }

  return __DARWIN__
    ? t('menu.labels.forcePush2')
    : t('menu.labels.forcePushAccessKey2')
}

function getStashedChangesLabel(isStashedChangesVisible: boolean): string {
  if (isStashedChangesVisible) {
    return __DARWIN__
      ? t('menu.labels.hideStashedChanges')
      : t('menu.labels.hideStashedChangesAccessKey')
  }

  return __DARWIN__
    ? t('menu.labels.showStashedChanges')
    : t('menu.labels.showStashedChangesAccessKey')
}

type ClickHandler = (
  menuItem: Electron.MenuItem,
  browserWindow: Electron.BaseWindow | undefined,
  event: Electron.KeyboardEvent
) => void

/**
 * Utility function returning a Click event handler which, when invoked, emits
 * the provided menu event over IPC.
 */
export function emit(name: MenuEvent): ClickHandler {
  return (_, focusedWindow) => {
    // focusedWindow can be null if the menu item was clicked without the window
    // being in focus. A simple way to reproduce this is to click on a menu item
    // while in DevTools. Since Desktop only supports one window at a time we
    // can be fairly certain that the first BrowserWindow we find is the one we
    // want.
    const window =
      focusedWindow instanceof BrowserWindow
        ? focusedWindow
        : BrowserWindow.getAllWindows()[0]
    if (window !== undefined) {
      if (!window.isVisible()) {
        window.show()
      }
      ipcWebContents.send(window.webContents, 'menu-event', name)
    }
  }
}

/** The zoom steps that we support, these factors must sorted */
const ZoomInFactors = [0.67, 0.75, 0.8, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2]
const ZoomOutFactors = ZoomInFactors.slice().reverse()

/**
 * Returns the element in the array that's closest to the value parameter. Note
 * that this function will throw if passed an empty array.
 */
function findClosestValue(arr: Array<number>, value: number) {
  return arr.reduce((previous, current) => {
    return Math.abs(current - value) < Math.abs(previous - value)
      ? current
      : previous
  })
}

/**
 * Figure out the next zoom level for the given direction and alert the renderer
 * about a change in zoom factor if necessary.
 */
function zoom(direction: ZoomDirection): ClickHandler {
  return (menuItem, window) => {
    if (!(window instanceof BrowserWindow)) {
      return
    }

    const { webContents } = window

    if (direction === ZoomDirection.Reset) {
      webContents.zoomFactor = 1
      ipcWebContents.send(webContents, 'zoom-factor-changed', 1)
    } else {
      const rawZoom = webContents.zoomFactor
      const zoomFactors =
        direction === ZoomDirection.In ? ZoomInFactors : ZoomOutFactors

      // So the values that we get from zoomFactor property are floating point
      // precision numbers from chromium, that don't always round nicely, so
      // we'll have to do a little trick to figure out which of our supported
      // zoom factors the value is referring to.
      const currentZoom = findClosestValue(zoomFactors, rawZoom)

      const nextZoomLevel = zoomFactors.find(f =>
        direction === ZoomDirection.In ? f > currentZoom : f < currentZoom
      )

      // If we couldn't find a zoom level (likely due to manual manipulation
      // of the zoom factor in devtools) we'll just snap to the closest valid
      // factor we've got.
      const newZoom = nextZoomLevel === undefined ? currentZoom : nextZoomLevel

      webContents.zoomFactor = newZoom
      ipcWebContents.send(webContents, 'zoom-factor-changed', newZoom)
    }
  }
}
