import { register as registerDiffCommit } from './handlers/diff-commit'
import { register as registerStatusHistory } from './handlers/status-history'
import { register as registerBranchesSync } from './handlers/branches-sync'

/**
 * Registers the `git:*` IPC handlers declared in `src/shared/ipc/git.ts`.
 * Each group is owned by one N1 worker so they never edit the same file:
 *
 * - diff-commit (G1): git:workingDiff, git:commitDiff, git:commit, git:discardLines
 * - status-history (G2): git:status, git:discard, git:log, git:commitFiles, repo watcher
 * - branches-sync (G3): git:branches, git:createBranch, git:checkout, git:renameBranch,
 *   git:deleteBranch, git:remotes, git:fetch, git:pull, git:push, git:clone
 */
export function registerGitHandlers(): void {
  registerDiffCommit()
  registerStatusHistory()
  registerBranchesSync()
}
