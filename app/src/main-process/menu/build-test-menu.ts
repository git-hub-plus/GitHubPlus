import { t } from '../../lib/i18n'
import { MenuItemConstructorOptions } from 'electron'
import { enableTestMenuItems } from '../../lib/feature-flag'
import { emit, separator } from './build-default-menu'

export function buildTestMenu() {
  if (!enableTestMenuItems()) {
    return []
  }

  const testMenuItems: MenuItemConstructorOptions[] = []

  if (__WIN32__) {
    testMenuItems.push(separator, {
      label: t('menu.test.commandLineTool'),
      submenu: [
        {
          label: t('menu.test.install'),
          click: emit('install-windows-cli'),
        },
        {
          label: t('menu.test.uninstall'),
          click: emit('uninstall-windows-cli'),
        },
      ],
    })
  }

  const errorDialogsSubmenu: MenuItemConstructorOptions[] = [
    {
      label: t('menu.test.confirmConflicted'),
      click: emit('test-confirm-committing-conflicted-files'),
    },
    {
      label: t('menu.test.discardUnrecoverable'),
      click: emit('test-discarded-changes-will-be-unrecoverable'),
    },
    {
      label: t('menu.test.forkRepository'),
      click: emit('test-do-you-want-fork-this-repository'),
    },
    {
      label: t('menu.test.newerCommits'),
      click: emit('test-newer-commits-on-remote'),
    },
    {
      label: t('menu.test.filesTooLarge'),
      click: emit('test-files-too-large'),
    },
    {
      label: t('menu.test.gitAuthentication'),
      click: emit('test-generic-git-authentication'),
    },
    {
      label: t('menu.test.invalidToken'),
      click: emit('test-invalidated-account-token'),
    },
  ]

  if (__DARWIN__) {
    errorDialogsSubmenu.push({
      label: t('menu.test.moveApplication'),
      click: emit('test-move-to-application-folder'),
    })
  }

  errorDialogsSubmenu.push(
    {
      label: t('menu.test.pushRejected'),
      click: emit('test-push-rejected'),
    },
    {
      label: t('menu.test.reauthorization'),
      click: emit('test-re-authorization-required'),
    },
    {
      label: t('menu.test.locateGit'),
      click: emit('test-unable-to-locate-git'),
    },
    {
      label: t('menu.test.openEditor'),
      click: emit('test-no-external-editor'),
    },
    {
      label: t('menu.test.openShell'),
      click: emit('test-unable-to-open-shell'),
    },
    {
      label: t('menu.test.untrustedServer'),
      click: emit('test-untrusted-server'),
    },
    {
      label: t('menu.test.updateLfs'),
      click: emit('test-update-existing-git-lfs-filters'),
    },
    {
      label: t('menu.test.upstreamExists'),
      click: emit('test-upstream-already-exists'),
    }
  )

  testMenuItems.push(
    separator,
    {
      label: t('menu.test.crashMain'),
      click() {
        throw new Error('Boomtown!')
      },
    },
    {
      label: t('menu.test.crashRenderer'),
      click: emit('boomtown'),
    },
    {
      label: t('menu.test.pruneBranches'),
      click: emit('test-prune-branches'),
    },
    {
      label: t('menu.test.notification'),
      click: emit('test-notification'),
    },
    {
      label: t('menu.test.cliAction'),
      click: emit('test-cli-action'),
    },
    {
      label: t('menu.test.stats'),
      click: emit('test-send-stats'),
    },
    {
      label: t('menu.test.popup'),
      submenu: [
        {
          label: t('menu.test.releaseNotes'),
          click: emit('test-release-notes-popup'),
        },
        {
          label: t('menu.test.thankYou'),
          click: emit('test-thank-you-popup'),
        },
        {
          label: t('menu.test.appError'),
          click: emit('test-app-error'),
        },
        {
          label: t('menu.test.octicons'),
          click: emit('test-icons'),
        },
        {
          label: t('menu.test.about'),
          click: emit('test-about-dialog'),
        },
        {
          label: t('menu.test.copilotSnapshot'),
          click: emit('test-copilot-snapshot-card'),
        },
        {
          label: t('menu.test.tokenExpiration'),
          click: emit('test-token-expiration'),
        },
      ],
    },
    {
      label: t('menu.test.banner'),
      submenu: [
        {
          label: t('menu.test.updateBanner'),
          click: emit('test-update-banner'),
        },
        {
          label: t('menu.test.priorityBanner'),
          click: emit('test-prioritized-update-banner'),
        },
        {
          label: t('menu.test.showcaseBanner'),
          click: emit('test-showcase-update-banner'),
        },
        {
          label: t('menu.test.architectureBanner', {
            architecture: __DARWIN__ ? 'Apple silicon' : 'Arm64',
          }),
          click: emit('test-arm64-banner'),
        },
        {
          label: t('menu.test.thankYou'),
          click: emit('test-thank-you-banner'),
        },
        {
          label: t('menu.test.reorderSuccess'),
          click: emit('test-reorder-banner'),
        },
        {
          label: t('menu.test.reorderUndone'),
          click: emit('test-undone-banner'),
        },
        {
          label: t('menu.test.cherryPickConflicts'),
          click: emit('test-cherry-pick-conflicts-banner'),
        },
        {
          label: t('menu.test.mergeSuccess'),
          click: emit('test-merge-successful-banner'),
        },
        {
          label: t('menu.test.unsupportedOs'),
          click: emit('test-os-version-no-longer-supported'),
        },
      ],
    },
    {
      label: t('menu.test.errorDialogs'),
      submenu: errorDialogsSubmenu,
    }
  )

  return testMenuItems
}
