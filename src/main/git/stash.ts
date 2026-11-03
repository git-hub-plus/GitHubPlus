// Ported from GitHub Desktop (MIT): app/src/lib/git/stash.ts
import { HandlerError } from '@shared/errors'
import type { StashEntry, CommittedFile } from '@shared/models/git'
import { git } from './core'
import { getCommitFiles } from './log'
import { getCommitDiff, validatePath } from './diff'
import { resolveCommit } from './rev-parse'
import { runOperation } from './merge'

export async function stashList(repoPath: string): Promise<StashEntry[]> {
  const result = await git(
    ['stash', 'list', '--format=%gd%x00%H%x00%gs%x00%ct'],
    repoPath,
    'stashList'
  )
  return result.stdout
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      const [name, sha, message, date] = line.split('\0')
      return {
        name,
        sha,
        message,
        createdAt: Number(date) * 1000,
        branchName: /^(?:WIP on|On) (.*?): /.exec(message)?.[1] ?? '',
      }
    })
}
async function stashEntry(repoPath: string, name: string): Promise<StashEntry> {
  const entry = (await stashList(repoPath)).find(
    (entry) => entry.name === name || entry.sha === name
  )
  if (!entry) throw new HandlerError('invalid-argument', 'Unknown stash')
  return entry
}
export async function stashCreate(
  repoPath: string,
  opts?: { message?: string; includeUntracked?: boolean }
): Promise<void> {
  await git(
    [
      'stash',
      'push',
      ...(opts?.includeUntracked ? ['--include-untracked'] : []),
      ...(opts?.message !== undefined ? ['-m', opts.message] : []),
    ],
    repoPath,
    'stashCreate'
  )
}
export async function stashApply(repoPath: string, name: string, opts?: { pop?: boolean }) {
  const entry = await stashEntry(repoPath, name)
  return runOperation(repoPath, ['stash', opts?.pop ? 'pop' : 'apply', entry.name])
}
export async function stashDrop(repoPath: string, name: string): Promise<void> {
  const entry = await stashEntry(repoPath, name)
  await git(['stash', 'drop', entry.name], repoPath, 'stashDrop')
}
async function stashParts(repoPath: string, name: string) {
  const entry = await stashEntry(repoPath, name)
  return { sha: entry.sha, untracked: await resolveCommit(repoPath, `${entry.sha}^3`) }
}
export async function stashFiles(repoPath: string, name: string): Promise<CommittedFile[]> {
  const { sha, untracked } = await stashParts(repoPath, name)
  return [
    ...(await getCommitFiles(repoPath, sha)),
    ...(untracked ? await getCommitFiles(repoPath, untracked) : []),
  ]
}
export async function stashDiff(repoPath: string, name: string, path: string) {
  validatePath(repoPath, path)
  const { sha, untracked } = await stashParts(repoPath, name)
  const tracked = (await getCommitFiles(repoPath, sha)).find((file) => file.path === path)
  if (tracked) return getCommitDiff(repoPath, sha, tracked)
  const file =
    untracked && (await getCommitFiles(repoPath, untracked)).find((file) => file.path === path)
  if (!file || !untracked) throw new HandlerError('not-found', 'File is not in stash')
  return getCommitDiff(repoPath, untracked, file)
}
