// Ported from GitHub Desktop (MIT): app/src/lib/git/push.ts
import { HandlerError } from '@shared/errors'
import { git, GitError, classifyGitError } from './core'
import { getConfigValue } from './config'
import { runWithProgress, type ProgressCallback } from './progress/from-process'

export async function push(
  path: string,
  opts: { remote?: string; branch?: string; setUpstream?: boolean },
  progress?: ProgressCallback
): Promise<void> {
  const branch =
    opts.branch ??
    (await git(['symbolic-ref', '--quiet', '--short', 'HEAD'], path, 'pushBranch')).stdout.trim()
  // Validate as a branch rather than allowing refspecs supplied by the caller.
  await git(['check-ref-format', '--branch', branch], path, 'validatePushBranch')
  const configuredRemote = await getConfigValue(path, `branch.${branch}.remote`)
  const merge = await getConfigValue(path, `branch.${branch}.merge`)
  if ((!configuredRemote || !merge) && !opts.setUpstream)
    throw new HandlerError('no-upstream', `No upstream for ${branch}`)
  const remote = opts.remote ?? configuredRemote ?? 'origin'
  const target =
    !opts.setUpstream && remote === configuredRemote && merge ? merge : `refs/heads/${branch}`
  try {
    await runWithProgress(
      [
        'push',
        '--progress',
        ...(opts.setUpstream ? ['--set-upstream'] : []),
        '--',
        remote,
        `refs/heads/${branch}:${target}`,
      ],
      path,
      'push',
      'Pushing',
      progress
    )
  } catch (error) {
    if (
      error instanceof GitError &&
      classifyGitError(error.result.gitError) === 'unknown' &&
      /\[rejected\]|\[remote rejected\]/.test(error.result.stderr)
    ) {
      throw new HandlerError(
        /\(fetch first\)|\(non-fast-forward\)/.test(error.result.stderr)
          ? 'push-needs-pull'
          : 'push-rejected',
        error.message,
        error.result.stderr
      )
    }
    throw error
  }
}
