import { watch, type FSWatcher } from 'node:fs'
import { isAbsolute, relative, resolve } from 'node:path'
import { git } from './git/core'
import { getGitPath } from './git/rev-parse'

export interface RepositoryWatchOptions {
  readonly debounceMs?: number
  readonly onError?: (error: Error) => void
}

/** Watches worktree and git metadata, including gitdirs outside linked worktrees. */
export async function createRepositoryWatcher(
  repoPath: string,
  onChange: () => void,
  options: RepositoryWatchOptions = {}
): Promise<() => void> {
  const root = resolve(repoPath)
  const gitDir = await getGitPath(root, '.')
  const common = await git(['rev-parse', '--git-common-dir'], root, 'watchCommonGitDir')
  const commonDir = resolve(root, common.stdout.replace(/\r?\n$/, ''))
  const watchers: FSWatcher[] = []
  let timer: ReturnType<typeof setTimeout> | undefined
  let closed = false
  const schedule = () => {
    if (closed) return
    clearTimeout(timer)
    timer = setTimeout(() => {
      if (!closed) onChange()
    }, options.debounceMs ?? 300)
  }
  const stop = () => {
    closed = true
    clearTimeout(timer)
    for (const watcher of watchers) watcher.close()
  }
  const metadata = (path: string) =>
    /^(HEAD|index|packed-refs|config|shallow|MERGE_HEAD|MERGE_MSG|CHERRY_PICK_HEAD|REVERT_HEAD|ORIG_HEAD)$/.test(
      path
    ) ||
    /^(refs|rebase-merge|rebase-apply|sequencer)(\/|$)/.test(path) ||
    path === 'logs/refs/stash'
  const add = (directory: string, include: (path: string) => boolean) => {
    const watcher = watch(directory, { recursive: true }, (_event, filename) => {
      if (filename === null || include(filename.toString().replace(/\\/g, '/'))) schedule()
    })
    watcher.on('error', (error) => {
      stop()
      options.onError?.(error)
    })
    watchers.push(watcher)
  }
  try {
    add(root, (path) => {
      if (path === '.git') return true
      if (path.startsWith('.git/')) return false
      const fromGitDir = relative(gitDir, resolve(root, path))
      if (fromGitDir === '' || (!fromGitDir.startsWith('..') && !isAbsolute(fromGitDir)))
        return false
      return !path.split('/').includes('.git')
    })
    for (const directory of new Set([gitDir, commonDir])) add(directory, metadata)
  } catch (error) {
    stop()
    throw error
  }
  return stop
}

let stopActive: (() => void) | undefined
let generation = 0

/** Call after repos:open. Awaitable so setup failures can be reported by the caller. */
export async function watchRepository(repoId: string): Promise<void> {
  const request = ++generation
  stopActive?.()
  stopActive = undefined
  const [{ getRepository }, { broadcast }, { log }] = await Promise.all([
    import('./store/repositories'),
    import('./ipc'),
    import('./log'),
  ])
  if (request !== generation) return
  const stop = await createRepositoryWatcher(
    getRepository(repoId).path,
    () => {
      if (request === generation) broadcast('git:repoChanged', { repoId })
    },
    { onError: (error) => log.warn('Repository watcher stopped', error) }
  )
  if (request !== generation) stop()
  else stopActive = stop
}

export function stopWatchingRepository(): void {
  generation++
  stopActive?.()
  stopActive = undefined
}
