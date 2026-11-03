import { constants } from 'node:fs'
import { copyFile, lstat, mkdir, readdir, realpath } from 'node:fs/promises'
import { basename, isAbsolute, relative, resolve, sep } from 'node:path'
import { HandlerError } from '@shared/errors'
import { handle } from '../ipc'
import { getRepository } from '../store/repositories'

function inside(root: string, path: string): boolean {
  const suffix = relative(root, path)
  return suffix === '' || (!isAbsolute(suffix) && suffix !== '..' && !suffix.startsWith(`..${sep}`))
}

function invalid(): never {
  throw new HandlerError('invalid-argument', 'The copy target must be inside the working tree.')
}

/** Reject symbolic links, including junctions, before following destination ancestors. */
async function validateTarget(root: string, target: string): Promise<void> {
  if (!inside(root, target)) invalid()
  let current = root
  for (const part of relative(root, target).split(sep).filter(Boolean)) {
    if (part.toLowerCase() === '.git') invalid()
    current = resolve(current, part)
    try {
      const stat = await lstat(current)
      if (stat.isSymbolicLink() || !stat.isDirectory()) invalid()
      if (!inside(root, await realpath(current))) invalid()
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
    }
  }
}

export async function copyIntoRepository(
  repositoryPath: string,
  input: { sources: ReadonlyArray<string>; targetDirectory: string }
): Promise<{ copied: string[]; skipped: string[] }> {
  if (
    !Array.isArray(input.sources) ||
    !input.sources.length ||
    typeof input.targetDirectory !== 'string'
  )
    invalid()
  const root = await realpath(repositoryPath)
  const target = resolve(root, input.targetDirectory || '.')
  await validateTarget(root, target)
  const result = { copied: [] as string[], skipped: [] as string[] }
  const name = (path: string) => relative(root, path).split(sep).join('/')

  const copy = async (source: string, destination: string): Promise<void> => {
    if (basename(source).toLowerCase() === '.git') return
    const stat = await lstat(source)
    if (stat.isSymbolicLink() || (!stat.isFile() && !stat.isDirectory())) {
      result.skipped.push(name(destination))
      return
    }
    await validateTarget(root, resolve(destination, '..'))
    let existing
    try {
      existing = await lstat(destination)
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
    }
    if (existing && (!stat.isDirectory() || !existing.isDirectory() || existing.isSymbolicLink())) {
      result.skipped.push(name(destination))
      return
    }
    if (stat.isDirectory()) {
      if (inside(await realpath(source), destination)) invalid()
      await mkdir(destination, { recursive: true })
      for (const entry of await readdir(source))
        await copy(resolve(source, entry), resolve(destination, entry))
    } else {
      try {
        await copyFile(source, destination, constants.COPYFILE_EXCL)
        result.copied.push(name(destination))
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'EEXIST') throw error
        result.skipped.push(name(destination))
      }
    }
  }

  for (const source of input.sources) {
    if (typeof source !== 'string' || !isAbsolute(source)) invalid()
    const sourcePath = resolve(source)
    if (basename(sourcePath).toLowerCase() === '.git') continue
    const destination = resolve(target, basename(sourcePath))
    if (!inside(root, destination)) invalid()
    if ((await lstat(sourcePath)).isDirectory() && inside(await realpath(sourcePath), destination))
      invalid()
    await mkdir(target, { recursive: true })
    await copy(sourcePath, destination)
  }
  return result
}

export function register(): void {
  handle('files:copyIntoRepository', (_event, id, input) =>
    copyIntoRepository(getRepository(id).path, input)
  )
}
