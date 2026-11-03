// Ported from GitHub Desktop (MIT): app/src/lib/git/reset.ts
import { HandlerError } from '@shared/errors'
import { git } from './core'
import { getCommits } from './log'
import { getStatus } from './status'
export async function undoLastCommit(
  repoPath: string
): Promise<{ summary: string; description: string }> {
  if ((await getStatus(repoPath)).inProgress)
    throw new HandlerError('invalid-argument', 'An operation is in progress')
  const [commit] = await getCommits(repoPath, { limit: 1 })
  if (!commit) throw new HandlerError('invalid-argument', 'There is no commit to undo')
  const remotes = await git(
    ['for-each-ref', `--contains=${commit.sha}`, '--format=%(refname)', 'refs/remotes/'],
    repoPath,
    'publishedCommit'
  )
  if (remotes.stdout.trim())
    throw new HandlerError('invalid-argument', 'Cannot undo a pushed commit')
  if (commit.parentShas.length)
    await git(['reset', '--soft', `${commit.sha}~1`], repoPath, 'undoLastCommit')
  else await git(['update-ref', '-d', 'HEAD', commit.sha], repoPath, 'undoFirstCommit')
  return { summary: commit.summary, description: commit.body.trimEnd() }
}
