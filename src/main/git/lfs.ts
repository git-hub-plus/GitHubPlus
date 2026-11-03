// Ported from GitHub Desktop (MIT): app/src/lib/git/lfs.ts
import { readFile } from 'node:fs/promises'
import { isAbsolute, join } from 'node:path'
import type { LfsStatus } from '@shared/ipc/git-advanced'
import { HandlerError } from '@shared/errors'
import { git } from './core'

async function readOptional(path: string): Promise<string> {
  try {
    return await readFile(path, 'utf8')
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return ''
    throw error
  }
}

/** Root attributes only, including Git's quoted patterns and octal UTF-8 escapes. */
export function parseLfsPatterns(attributes: string): string[] {
  const patterns = new Set<string>()
  for (const line of attributes.split(/\r?\n/)) {
    if (/^\s*(?:#|$)/.test(line)) continue
    const match = /^\s*("(?:\\.|[^"\\])*"|\S+)\s+(.+)$/.exec(line)
    if (!match || !match[2].split(/\s+/).includes('filter=lfs')) continue
    let pattern = match[1]
    if (pattern.startsWith('"')) {
      const bytes: number[] = []
      const text = pattern.slice(1, -1)
      for (let index = 0; index < text.length;) {
        const escape = /^\\([0-7]{1,3}|[abfnrtv"\\])/.exec(text.slice(index))
        if (escape) {
          const value = escape[1]
          const controls: Record<string, number> = {
            a: 7,
            b: 8,
            f: 12,
            n: 10,
            r: 13,
            t: 9,
            v: 11,
            '"': 34,
            '\\': 92,
          }
          bytes.push(/^[0-7]/.test(value) ? parseInt(value, 8) : controls[value])
          index += escape[0].length
        } else {
          const char = String.fromCodePoint(text.codePointAt(index)!)
          bytes.push(...Buffer.from(char))
          index += char.length
        }
      }
      pattern = Buffer.from(bytes).toString('utf8')
    }
    patterns.add(pattern)
  }
  return [...patterns]
}

export async function getLfsStatus(path: string): Promise<LfsStatus> {
  const hook = await git(['rev-parse', '--git-path', 'hooks/pre-push'], path, 'getLfsHook')
  const hookPath = hook.stdout.trim()
  const [version, hookContent, attributes] = await Promise.all([
    git(['lfs', 'version'], path, 'getLfsVersion', { successExitCodes: new Set([0, 1]) }),
    readOptional(isAbsolute(hookPath) ? hookPath : join(path, hookPath)),
    readOptional(join(path, '.gitattributes')),
  ])
  return {
    available: version.exitCode === 0,
    installedInRepository: /\bgit\s+lfs\s+pre-push\b/.test(hookContent),
    trackedPatterns: parseLfsPatterns(attributes),
  }
}

export async function installLFSHooks(path: string): Promise<void> {
  await git(['lfs', 'install', '--local'], path, 'installLFSHooks')
}

async function changePattern(
  path: string,
  pattern: string,
  action: 'track' | 'untrack'
): Promise<void> {
  if (!pattern.trim() || /[\0\r\n]/.test(pattern)) {
    throw new HandlerError('invalid-argument', 'Invalid Git LFS pattern')
  }
  const status = await getLfsStatus(path)
  if (!status.available) throw new HandlerError('unknown', 'Git LFS is unavailable')
  if (!status.installedInRepository) await installLFSHooks(path)
  await git(['lfs', action, '--', pattern], path, `lfs${action}`)
}

export const trackLfsPattern = (path: string, pattern: string): Promise<void> =>
  changePattern(path, pattern, 'track')

export const untrackLfsPattern = (path: string, pattern: string): Promise<void> =>
  changePattern(path, pattern, 'untrack')

export async function isTrackedByLFS(path: string, file: string): Promise<boolean> {
  const { stdout } = await git(['check-attr', '-z', 'filter', '--', file], path, 'checkAttrForLFS')
  return stdout.split('\0')[2] === 'lfs'
}

export async function filesNotTrackedByLFS(
  path: string,
  files: ReadonlyArray<string>
): Promise<string[]> {
  const tracked = await Promise.all(files.map((file) => isTrackedByLFS(path, file)))
  return files.filter((_, index) => !tracked[index])
}
