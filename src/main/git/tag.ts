// Ported from GitHub Desktop (MIT): app/src/lib/git/tag.ts
import { HandlerError } from '@shared/errors'
import type { Tag } from '@shared/models/git'
import { git } from './core'
import { resolveCommit } from './diff'
import { runWithProgress, type ProgressCallback } from './progress/from-process'

async function tagRef(repoPath: string, name: string): Promise<string> {
  const ref = `refs/tags/${name}`
  const result = await git(['check-ref-format', ref], repoPath, 'validateTag', {
    successExitCodes: new Set([0, 1]),
  })
  if (!name || name.startsWith('-') || result.exitCode)
    throw new HandlerError('invalid-argument', 'Invalid tag name')
  return ref
}
export async function getTags(repoPath: string): Promise<Tag[]> {
  const result = await git(['show-ref', '--tags', '-d'], repoPath, 'tags', {
    successExitCodes: new Set([0, 1]),
  })
  const tags = new Map<string, string>()
  for (const line of result.stdout.trim().split('\n').filter(Boolean)) {
    const [sha, ref] = line.split(' ')
    tags.set(ref.replace(/^refs\/tags\//, '').replace(/\^\{\}$/, ''), sha)
  }
  return [...tags].map(([name, targetSha]) => ({ name, targetSha }))
}
export async function createTag(
  repoPath: string,
  input: { name: string; sha: string; message?: string }
): Promise<void> {
  await tagRef(repoPath, input.name)
  const sha = await resolveCommit(repoPath, input.sha)
  await git(
    [
      'tag',
      ...(input.message !== undefined ? ['-a', '-m', input.message] : ['--no-sign']),
      '--',
      input.name,
      sha,
    ],
    repoPath,
    'createTag'
  )
}
export async function deleteTag(
  repoPath: string,
  name: string,
  opts?: { remote?: string }
): Promise<void> {
  const ref = await tagRef(repoPath, name)
  // Delete remotely first so a rejected push leaves the local tag available.
  if (opts?.remote) await git(['push', '--', opts.remote, `:${ref}`], repoPath, 'deleteRemoteTag')
  await git(['tag', '-d', '--', name], repoPath, 'deleteTag')
}
export async function pushTag(
  repoPath: string,
  name: string,
  opts: { remote?: string },
  progress?: ProgressCallback
): Promise<void> {
  const ref = await tagRef(repoPath, name)
  await runWithProgress(
    ['push', '--progress', '--', opts.remote ?? 'origin', `${ref}:${ref}`],
    repoPath,
    'push',
    'Pushing tag',
    progress
  )
}
