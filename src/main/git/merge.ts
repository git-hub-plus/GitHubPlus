// Ported from GitHub Desktop (MIT): app/src/lib/git/merge.ts
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { AppFileStatusKind } from '@shared/models/status'
import { git, GitError, type GitOptions } from './core'
import { getStatus } from './status'
import { resolveCommit } from './diff'

/** Only actual unmerged index entries turn a failed command into conflicts. */
export async function runOperation(
  repoPath: string,
  args: string[],
  options: GitOptions = {}
): Promise<OperationOutcome> {
  try {
    const result = await git(args, repoPath, 'advancedOperation', {
      ...options,
      env: { GIT_EDITOR: 'true', ...options.env },
    })
    return /^(?:Already up.to.date\.?|Current branch .+ is up to date\.|nothing to commit[^\n]*)$/im.test(
      result.stdout
    )
      ? 'nothing-to-do'
      : 'success'
  } catch (error) {
    if (
      error instanceof GitError &&
      (await getStatus(repoPath)).files.some(
        (file) => file.status.kind === AppFileStatusKind.Conflicted
      )
    )
      return 'conflicts'
    throw error
  }
}

export async function merge(
  repoPath: string,
  branch: string,
  opts?: { squash?: boolean }
): Promise<OperationOutcome> {
  const sha = await resolveCommit(repoPath, branch)
  return runOperation(repoPath, ['merge', '--no-edit', ...(opts?.squash ? ['--squash'] : []), sha])
}
