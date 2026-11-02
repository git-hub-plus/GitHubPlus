// Ported from GitHub Desktop (MIT): app/src/lib/git/remote.ts
import type { Remote } from '@shared/models/git'
import { git } from './core'

/** First fetch URL per remote, including includes and Git's insteadOf rewrites. */
export async function getRemotes(path: string): Promise<ReadonlyArray<Remote>> {
  const { stdout } = await git(
    ['config', '--null', '--get-regexp', '^remote\\..+\\.url$'],
    path,
    'getRemotes',
    { successExitCodes: new Set([0, 1]) }
  )
  const names = new Set<string>()
  for (const entry of stdout.split('\0').filter(Boolean)) {
    const separator = entry.indexOf('\n')
    if (separator === -1) throw new Error('Remote URL configuration is missing a value')
    const name = entry.slice('remote.'.length, separator - '.url'.length)
    if (entry.slice(separator + 1).length === 0) names.delete(name)
    else names.add(name)
  }
  const remotes: Remote[] = []
  for (const name of [...names].sort()) {
    const result = await git(
      ['-c', 'transfer.credentialsInUrl=allow', 'ls-remote', '--get-url', '--', name],
      path,
      'getRemotes'
    )
    remotes.push({ name, url: result.stdout.slice(0, -1) })
  }
  return remotes
}
