// Ported from GitHub Desktop (MIT): app/src/lib/git/pull.ts
import { git } from './core'
import { getConfigValue } from './config'
import { runWithProgress, type ProgressCallback } from './progress/from-process'

export async function pull(
  path: string,
  remote?: string,
  progress?: ProgressCallback
): Promise<void> {
  const head = await git(['symbolic-ref', '--quiet', '--short', 'HEAD'], path, 'pullBranch', {
    successExitCodes: new Set([0, 1]),
  })
  const branchRebase =
    head.exitCode === 0
      ? await getConfigValue(path, `branch.${head.stdout.trim()}.rebase`)
      : undefined
  const rebase = branchRebase ?? (await getConfigValue(path, 'pull.rebase'))
  await runWithProgress(
    [
      'pull',
      '--progress',
      '--no-edit',
      ...(rebase === undefined ? ['--no-rebase'] : []),
      ...(remote ? ['--', remote] : []),
    ],
    path,
    'pull',
    'Pulling',
    progress
  )
}
