import type { RepositoryInfo } from '@shared/models/app'

/** An extra item for the sidebar's repository context menu. */
export interface RepositoryMenuItem {
  readonly label: string
  onSelect(repository: RepositoryInfo): void
}
