// Ported from GitHub Desktop (MIT): app/src/lib/git/fetch.ts
import { runWithProgress, type ProgressCallback } from './progress/from-process'

export async function fetch(
  path: string,
  remote?: string,
  progress?: ProgressCallback
): Promise<void> {
  await runWithProgress(
    ['fetch', '--prune', '--progress', ...(remote ? ['--', remote] : [])],
    path,
    'fetch',
    'Fetching',
    progress
  )
}
