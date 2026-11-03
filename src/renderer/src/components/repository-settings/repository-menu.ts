import type { RepositoryInfo } from '@shared/models/app'
import type { RepositoryMenuItem } from '../../lib/repository-menu'
import { t } from '@shared/i18n'
import { openRepositorySettings } from './RepositorySettingsDialog'

/** Sidebar context menu items for repository settings. Owner: C3. */
export function repositorySettingsMenuItems(repository: RepositoryInfo): RepositoryMenuItem[] {
  return repository.available
    ? [{ label: t('lfs.settings.title'), onSelect: openRepositorySettings }]
    : []
}
