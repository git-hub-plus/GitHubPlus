import { mkdtemp, rm, writeFile, mkdir } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { exec } from 'dugite'
import { afterEach, vi } from 'vitest'

// The git core imports logging; no Electron runtime or user-data writes in unit tests.
vi.mock('../../../src/main/log', () => ({ log: { warn: vi.fn(), error: vi.fn() } }))
const roots: string[] = []
afterEach(async () => {
  await Promise.all(
    roots
      .splice(0)
      .map((root) => rm(root, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 }))
  )
})
export async function run(path: string, args: string[], codes = [0]): Promise<string> {
  const result = await exec(
    [
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.com',
      '-c',
      'commit.gpgsign=false',
      '-c',
      'tag.gpgsign=false',
      '-c',
      'core.autocrlf=false',
      ...args,
    ],
    path,
    {
      env: {
        GIT_CONFIG_NOSYSTEM: '1',
        GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
      },
    }
  )
  if (!codes.includes(result.exitCode)) throw new Error(`git ${args.join(' ')}: ${result.stderr}`)
  return result.stdout.trim()
}
export async function repository(): Promise<string> {
  const root = await mkdtemp(join(tmpdir(), 'ghp-g2-'))
  roots.push(root)
  await run(root, ['init', '-b', 'main'])
  // Also applies to git calls made through the implementation under test.
  await run(root, ['config', 'core.autocrlf', 'false'])
  return root
}
export async function file(root: string, path: string, content = 'original\n'): Promise<void> {
  await mkdir(dirname(join(root, path)), { recursive: true })
  await writeFile(join(root, path), content)
}
export async function commit(root: string, message: string): Promise<string> {
  await run(root, ['add', '-A'])
  await run(root, ['commit', '--allow-empty', '-m', message])
  return run(root, ['rev-parse', 'HEAD'])
}
