// Ported from GitHub Desktop (MIT): app/src/lib/git/checkout.ts
// Ported from GitHub Desktop (MIT): app/src/lib/git/reset.ts
import { lstat, realpath } from 'node:fs/promises'
import { dirname, isAbsolute, relative, resolve } from 'node:path'
import { AppFileStatusKind as Kind } from '@shared/models/status'
import { git } from './core'
import { getStatus } from './status'
import { resolveCommit } from './rev-parse'

export type TrashItem = (path: string) => Promise<void>
function inside(root: string, path: string): boolean {
  const value = relative(root, path)
  return (
    value !== '' &&
    value !== '..' &&
    !value.startsWith(`..${process.platform === 'win32' ? '\\' : '/'}`) &&
    !isAbsolute(value)
  )
}

async function validateParent(root: string, path: string): Promise<void> {
  let parent = dirname(resolve(root, path))
  for (;;) {
    try {
      const canonical = await realpath(parent)
      if (canonical !== root && !inside(root, canonical))
        throw new Error('Discard path escapes repository')
      return
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
      const next = dirname(parent)
      if (next === parent) throw error
      parent = next
    }
  }
}

/** Discard only explicit changed files. New files go through Electron's recoverable trash. */
export async function discardFiles(
  repoPath: string,
  paths: ReadonlyArray<string>,
  trashItem?: TrashItem
): Promise<void> {
  if (paths.length === 0) return
  const root = await realpath(repoPath)
  const status = await getStatus(repoPath)
  const selected = [...new Set(paths)].map((path) => {
    if (
      isAbsolute(path) ||
      !inside(root, resolve(root, path)) ||
      path.split(/[\\/]/).some((part) => part.toLowerCase() === '.git')
    )
      throw new Error('Invalid discard path')
    const file = status.files.find((file) => file.path === path)
    if (!file) throw new Error(`Not a changed file: ${path}`)
    return file
  })
  // Resolve parents to prevent traversal through a symlink while allowing a symlink itself to be discarded.
  for (const file of selected) {
    await validateParent(root, file.path)
    if (file.status.kind === Kind.Renamed) await validateParent(root, file.status.oldPath)
  }
  const hasHead = await resolveCommit(repoPath)
  const candidates = selected.flatMap((file) =>
    file.status.kind === Kind.Renamed ? [file.path, file.status.oldPath] : [file.path]
  )
  const tree = hasHead
    ? await git(
        ['--literal-pathspecs', 'ls-tree', '-r', '-z', '--name-only', hasHead, '--', ...candidates],
        repoPath,
        'discardHeadFiles'
      )
    : undefined
  const headPaths = new Set(tree?.stdout.split('\0').filter(Boolean) ?? [])
  const restore = new Set<string>()
  const remove: string[] = []
  for (const file of selected) {
    if (headPaths.has(file.path)) restore.add(file.path)
    else remove.push(file.path)
    if (file.status.kind === Kind.Renamed && headPaths.has(file.status.oldPath))
      restore.add(file.status.oldPath)
  }
  const trash =
    trashItem ?? (async (path: string) => (await import('electron')).shell.trashItem(path))
  // Trash first: a failed trash operation must never silently destroy an untracked file.
  for (const path of remove) {
    try {
      await lstat(resolve(root, path))
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') continue
      throw error
    }
    await trash(resolve(root, path))
  }
  const literal = (path: string) => `:(literal)${path}`
  const stagedNew = selected
    .filter((file) => remove.includes(file.path) && file.status.kind !== Kind.Untracked)
    .map((file) => file.path)
  if (stagedNew.length)
    await git(
      ['rm', '--cached', '-f', '--ignore-unmatch', '--', ...stagedNew.map(literal)],
      repoPath,
      'discardAddedIndexEntries'
    )
  if (restore.size && hasHead)
    await git(
      ['restore', '--source=HEAD', '--staged', '--worktree', '--', ...[...restore].map(literal)],
      repoPath,
      'discardFiles'
    )
}
