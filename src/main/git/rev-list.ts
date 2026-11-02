// Ported from GitHub Desktop (MIT): app/src/lib/git/rev-list.ts
import { git, DugiteError } from './core'
export async function getAheadBehind(
  repoPath: string,
  range: string
): Promise<{ ahead: number; behind: number } | null> {
  const result = await git(
    ['rev-list', '--left-right', '--count', '--end-of-options', range, '--'],
    repoPath,
    'getAheadBehind',
    { expectedErrors: new Set([DugiteError.BadRevision]) }
  )
  if (result.gitError) return null
  const match = /^(\d+)\s+(\d+)\s*$/.exec(result.stdout)
  return match ? { ahead: Number(match[1]), behind: Number(match[2]) } : null
}
