// Ported from GitHub Desktop (MIT): app/src/lib/git/revert.ts
import { getCommits } from './log'
import { resolveCommit } from './diff'
import { runOperation } from './merge'
export async function revert(repoPath: string, ref: string) {
  const sha = await resolveCommit(repoPath, ref)
  const [commit] = await getCommits(repoPath, { ref: sha, limit: 1 })
  return runOperation(repoPath, [
    'revert',
    '--no-edit',
    ...(commit.parentShas.length > 1 ? ['-m', '1'] : []),
    sha,
  ])
}
