import { createElement } from 'react'
import { createRoot } from 'react-dom/client'
import type { RepositoryInfo } from '@shared/models/app'
import { t } from '@shared/i18n'
import type { RepositoryMenuItem } from '../../lib/repository-menu'
import { GitHubPublishDialog } from './GitHubPublishDialog'

let dismiss: (() => void) | undefined

/** The sidebar extension owns its dialog host; shared sidebar stays untouched. */
export function githubRepositoryMenuItems(repository: RepositoryInfo): RepositoryMenuItem[] {
  if (repository.group !== 'local') return []
  return [
    {
      label: t('github.publishMenu'),
      onSelect(selected) {
        dismiss?.()
        const host = document.createElement('div')
        document.body.append(host)
        const root = createRoot(host)
        const close = () => {
          root.unmount()
          host.remove()
          dismiss = undefined
        }
        dismiss = close
        root.render(createElement(GitHubPublishDialog, { repository: selected, onClose: close }))
      },
    },
  ]
}
