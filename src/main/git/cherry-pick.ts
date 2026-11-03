// Ported from GitHub Desktop (MIT): app/src/lib/git/cherry-pick.ts
import { HandlerError } from '@shared/errors'
import { git } from './core'
import { resolveCommit } from './diff'
import { runOperation } from './merge'

export async function cherryPick(repoPath: string, shas: ReadonlyArray<string>) {
  if (!shas.length) return 'nothing-to-do' as const
  const commits = await Promise.all(shas.map((sha) => resolveCommit(repoPath, sha)))
  for (const sha of commits) {
    const parents = (
      await git(['rev-list', '--parents', '-n', '1', sha, '--'], repoPath, 'cherryPickParents')
    ).stdout
      .trim()
      .split(' ')
    if (parents.length > 2)
      throw new HandlerError('invalid-argument', 'Cherry-pick cannot include merge commits')
  }
  return runOperation(repoPath, ['cherry-pick', ...commits])
}
