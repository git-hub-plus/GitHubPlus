// Ported from GitHub Desktop (MIT): app/src/lib/git/submodule.ts
import { StringDecoder } from 'node:string_decoder'
import { join, posix } from 'node:path'
import type { Submodule } from '@shared/ipc/git-advanced'
import { git } from './core'
import type { ProgressCallback } from './progress/from-process'

export function parseSubmoduleStatus(output: string): Submodule[] {
  return output.split(/\r?\n/).flatMap((line) => {
    const match = /^([ +\-U])([0-9a-f]{40,64}) (.+?)(?: \(.+\))?$/.exec(line)
    if (!match) return []
    const status: Submodule['status'] =
      match[1] === '+'
        ? 'out-of-date'
        : match[1] === '-'
          ? 'uninitialized'
          : match[1] === 'U'
            ? 'conflicted'
            : 'up-to-date'
    return [{ path: match[3], sha: match[2], status }]
  })
}

async function moduleUrls(path: string): Promise<Map<string, string>> {
  const { stdout } = await git(
    ['config', '-z', '--file', '.gitmodules', '--get-regexp', '^submodule\\..*\\.(path|url)$'],
    path,
    'getSubmoduleUrls',
    { successExitCodes: new Set([0, 1]) }
  )
  const modules = new Map<string, { path?: string; url?: string }>()
  for (const entry of stdout.split('\0')) {
    const newline = entry.indexOf('\n')
    if (newline < 0) continue
    const match = /^submodule\.(.*)\.(path|url)$/.exec(entry.slice(0, newline))
    if (!match) continue
    const module = modules.get(match[1]) ?? {}
    module[match[2] as 'path' | 'url'] = entry.slice(newline + 1)
    modules.set(match[1], module)
  }
  return new Map(
    [...modules.values()].flatMap((module) =>
      module.path && module.url ? [[module.path, module.url]] : []
    )
  )
}

export async function listSubmodules(path: string): Promise<Submodule[]> {
  const { stdout } = await git(['submodule', 'status', '--recursive'], path, 'listSubmodules')
  const modules = parseSubmoduleStatus(stdout)
  const urls = new Map<string, Map<string, string>>()
  for (const module of modules) {
    const parent =
      modules
        .filter((candidate) => module.path.startsWith(candidate.path + '/'))
        .sort((a, b) => b.path.length - a.path.length)[0]?.path ?? ''
    if (!urls.has(parent)) urls.set(parent, await moduleUrls(join(path, parent)))
  }
  return modules.map((module) => {
    const parent =
      [...urls.keys()]
        .filter((prefix) => !prefix || module.path.startsWith(prefix + '/'))
        .sort((a, b) => b.length - a.length)[0] ?? ''
    const relative = parent ? posix.relative(parent, module.path) : module.path
    return { ...module, url: urls.get(parent)?.get(relative) }
  })
}

export async function updateSubmodules(path: string, callback?: ProgressCallback): Promise<void> {
  const title = 'Updating submodules'
  callback?.({ kind: 'generic', title, value: 0 })
  const decoder = new StringDecoder('utf8')
  let pending = ''
  let count = 0
  const consume = (chunk: string): void => {
    pending += chunk
    const lines = pending.split(/[\r\n]/)
    pending = lines.pop() ?? ''
    for (const line of lines.filter(Boolean)) {
      if (/^(?:Submodule path .*: checked out |Cloning into )/.test(line)) count += 1
      callback?.({ kind: 'generic', title, value: 1 - Math.exp(-count * 0.25), description: line })
    }
  }
  await git(['submodule', 'update', '--init', '--recursive'], path, 'updateSubmodules', {
    processCallback: callback
      ? (process) => {
          const write = (chunk: Buffer): void => consume(decoder.write(chunk))
          process.stdout?.on('data', write)
          process.stderr?.on('data', write)
        }
      : undefined,
  })
  consume(decoder.end() + '\n')
  callback?.({ kind: 'generic', title, value: 1 })
}
