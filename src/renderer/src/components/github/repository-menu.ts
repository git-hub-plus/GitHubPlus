import type { RepositoryInfo } from '@shared/models/app'
import type { RepositoryMenuItem } from '../../lib/repository-menu'

/** Sidebar context menu items for GitHub (e.g. "GitHub에 게시…"). Owner: C1. */
export function githubRepositoryMenuItems(_repository: RepositoryInfo): RepositoryMenuItem[] {
  return []
}
