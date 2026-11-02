// Ported from GitHub Desktop (MIT): app/src/lib/git/rev-parse.ts
import { resolve } from 'node:path'
import { git } from './core'
export async function resolveCommit(repoPath: string, ref = 'HEAD'): Promise<string | undefined> {
  const result = await git(
    ['rev-parse', '--verify', '--quiet', '--end-of-options', `${ref}^{commit}`],
    repoPath,
    'resolveCommit',
    { successExitCodes: new Set([0, 1]) }
  )
  return result.exitCode === 0 ? result.stdout.trim() : undefined
}
export async function getGitPath(repoPath: string, name: string): Promise<string> {
  const result = await git(['rev-parse', '--git-path', name], repoPath, 'getGitPath')
  return resolve(repoPath, result.stdout.replace(/\r?\n$/, ''))
}
