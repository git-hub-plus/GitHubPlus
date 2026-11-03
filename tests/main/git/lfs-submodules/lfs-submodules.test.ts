// Ported from GitHub Desktop (MIT): app/test/unit/git/lfs-test.ts and submodule-test.ts
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve, sep } from 'node:path'
import { exec } from 'dugite'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { IpcChannel, IpcContract } from '../../../../src/shared/ipc'

const mocks = vi.hoisted(() => ({
  path: '',
  handlers: new Map<string, (...args: unknown[]) => unknown>(),
  broadcast: vi.fn(),
}))
vi.mock('../../../../src/main/log', () => ({ log: { warn: vi.fn() } }))
vi.mock('../../../../src/main/ipc', () => ({
  handle: (channel: string, handler: (...args: unknown[]) => unknown) =>
    mocks.handlers.set(channel, handler),
  broadcast: mocks.broadcast,
}))
vi.mock('../../../../src/main/store/repositories', () => ({
  getRepository: () => ({ path: mocks.path }),
}))

import { register } from '../../../../src/main/git/handlers/lfs-submodules'
import {
  filesNotTrackedByLFS,
  getLfsStatus,
  isTrackedByLFS,
  parseLfsPatterns,
  trackLfsPattern,
} from '../../../../src/main/git/lfs'
import {
  listSubmodules,
  parseSubmoduleStatus,
  updateSubmodules,
} from '../../../../src/main/git/submodule'
import { clone } from '../../../../src/main/git/clone'
import * as core from '../../../../src/main/git/core'

let root: string
let repo: string

async function git(path: string, ...args: string[]): Promise<string> {
  const result = await exec(
    [
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.com',
      '-c',
      'commit.gpgsign=false',
      ...args,
    ],
    path
  )
  if (result.exitCode !== 0) throw new Error(result.stderr)
  return result.stdout.trim()
}

async function invoke<C extends IpcChannel>(
  channel: C,
  ...args: Parameters<IpcContract[C]>
): Promise<ReturnType<IpcContract[C]>> {
  const handler = mocks.handlers.get(channel)
  if (!handler) throw new Error(`Missing handler: ${channel}`)
  return (await handler({}, ...args)) as ReturnType<IpcContract[C]>
}

beforeEach(async () => {
  vi.stubEnv('GIT_CONFIG_NOSYSTEM', '1')
  vi.stubEnv('GIT_CONFIG_GLOBAL', '')
  vi.stubEnv('GIT_TERMINAL_PROMPT', '0')
  root = await mkdtemp(join(tmpdir(), 'ghp-c3-'))
  repo = join(root, 'repo')
  await mkdir(repo)
  await git(repo, 'init', '--initial-branch=main')
  mocks.path = repo
  mocks.handlers.clear()
  mocks.broadcast.mockClear()
  register()
})

afterEach(async () => {
  vi.restoreAllMocks()
  vi.unstubAllEnvs()
  const target = resolve(root)
  if (
    !target.startsWith(resolve(tmpdir()) + sep) ||
    !target.split(sep).at(-1)?.startsWith('ghp-c3-')
  )
    throw new Error('Unsafe cleanup path')
  await rm(target, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
})

describe('LFS', () => {
  it('documents that clone does not hydrate LFS without preconfigured filters', async () => {
    await trackLfsPattern(repo, '*.psd')
    await writeFile(join(repo, 'image.psd'), 'image bytes')
    await git(repo, 'add', '.gitattributes', 'image.psd')
    await git(repo, 'commit', '-m', 'LFS file')
    const destination = join(root, 'lfs-clone')
    await clone({ opId: 'lfs-clone', url: repo, path: destination })
    expect(await readFile(join(destination, 'image.psd'), 'utf8')).toContain(
      'version https://git-lfs.github.com/spec/v1'
    )
    expect((await getLfsStatus(destination)).installedInRepository).toBe(false)
  })
  it('reports unavailable LFS while preserving the repository patterns', async () => {
    await writeFile(join(repo, '.gitattributes'), '*.psd filter=lfs\n')
    const original = core.git
    vi.spyOn(core, 'git').mockImplementation((async (...args: Parameters<typeof original>) =>
      args[0][0] === 'lfs' && args[0][1] === 'version'
        ? { stdout: '', stderr: 'not a git command', exitCode: 1, gitError: null, path: repo }
        : original(...args)) as typeof original)
    expect(await getLfsStatus(repo)).toEqual({
      available: false,
      installedInRepository: false,
      trackedPatterns: ['*.psd'],
    })
    await expect(trackLfsPattern(repo, '*.png')).rejects.toThrow('Git LFS is unavailable')
  })
  it('tracks and untracks through IPC, installs only local hooks and leaves attributes visible', async () => {
    expect(mocks.handlers.size).toBe(5)
    expect(await invoke('git:lfsStatus', 'repo')).toEqual({
      available: true,
      installedInRepository: false,
      trackedPatterns: [],
    })
    await invoke('git:lfsTrack', 'repo', '*.psd')
    expect(await invoke('git:lfsStatus', 'repo')).toEqual({
      available: true,
      installedInRepository: true,
      trackedPatterns: ['*.psd'],
    })
    expect(await readFile(join(repo, '.gitattributes'), 'utf8')).toContain('*.psd filter=lfs')
    expect(await git(repo, 'status', '--porcelain')).toContain('?? .gitattributes')
    expect(await git(repo, 'config', '--local', '--get', 'filter.lfs.process')).toBe(
      'git-lfs filter-process'
    )
    await invoke('git:lfsUntrack', 'repo', '*.psd')
    expect((await getLfsStatus(repo)).trackedPatterns).toEqual([])
    expect(await readFile(join(repo, '.gitattributes'), 'utf8')).not.toContain('filter=lfs')
  })

  it('ports tracking checks for Unicode paths, subdirectories, and non-LFS filters', async () => {
    await writeFile(join(repo, '.git', 'info', 'attributes'), '* filter=annex\n')
    expect(await isTrackedByLFS(repo, 'README.md')).toBe(false)
    expect((await getLfsStatus(repo)).trackedPatterns).toEqual([])
    await trackLfsPattern(repo, 'app/src/*.png')
    // info/attributes intentionally overrides working tree attributes.
    await writeFile(join(repo, '.git', 'info', 'attributes'), '*.bin filter=annex\n')
    expect(await isTrackedByLFS(repo, 'app/src/사진 Martín.png')).toBe(true)
    expect(await filesNotTrackedByLFS(repo, ['app/src/photo.png', 'video.mp4'])).toEqual([
      'video.mp4',
    ])
  })

  it('preserves an existing custom pre-push hook and rejects invalid patterns', async () => {
    const hook = '#!/bin/sh\necho custom\n'
    await writeFile(join(repo, '.git', 'hooks', 'pre-push'), hook)
    await expect(trackLfsPattern(repo, '*.psd')).rejects.toThrow()
    expect(await readFile(join(repo, '.git', 'hooks', 'pre-push'), 'utf8')).toBe(hook)
    await expect(trackLfsPattern(repo, '\n*.psd')).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })

  it('parses only filter=lfs patterns, quoted whitespace, escapes, and UTF-8 octal', () => {
    expect(
      parseLfsPatterns(
        '# comment filter=lfs\n*.bin filter=annex\n*.psd filter=lfs diff=lfs\n"assets/my file.psd" filter=lfs\n"\\353\\202\\230.psd" filter=lfs\n*.psd filter=lfs\n'
      )
    ).toEqual(['*.psd', 'assets/my file.psd', '나.psd'])
  })
})

describe('submodules', () => {
  it('resolves nested URLs from each containing .gitmodules and initializes recursively', async () => {
    vi.stubEnv('GIT_ALLOW_PROTOCOL', 'file')
    const leaf = join(root, 'leaf')
    const middle = join(root, 'middle')
    for (const directory of [leaf, middle]) {
      await mkdir(directory)
      await git(directory, 'init', '--initial-branch=main')
      await git(directory, 'commit', '--allow-empty', '-m', 'initial')
    }
    await git(middle, 'submodule', 'add', '--name', 'unrelated-name', leaf, 'nested')
    await git(middle, 'commit', '-m', 'nested')
    await git(repo, 'submodule', 'add', middle, 'outer')
    const before = await listSubmodules(repo)
    expect(before.map(({ path, url, status }) => ({ path, url, status }))).toEqual([
      { path: 'outer', url: middle, status: 'up-to-date' },
      { path: 'outer/nested', url: leaf, status: 'uninitialized' },
    ])
    await updateSubmodules(repo)
    expect((await listSubmodules(repo)).every((module) => module.status === 'up-to-date')).toBe(
      true
    )
  })
  it('parses all prefixes, missing describe output, whitespace, and SHA-256', () => {
    const sha = 'a'.repeat(40)
    expect(
      parseSubmoduleStatus(
        ` ${sha} one (heads/main)\n+${sha} folder/two with spaces (v1)\n-${sha} three\nU${'b'.repeat(64)} four\ninvalid`
      )
    ).toEqual([
      { path: 'one', sha, status: 'up-to-date' },
      { path: 'folder/two with spaces', sha, status: 'out-of-date' },
      { path: 'three', sha, status: 'uninitialized' },
      { path: 'four', sha: 'b'.repeat(64), status: 'conflicted' },
    ])
  })

  it('lists local bare submodules, detects changed checkout and updates with opId progress', async () => {
    const source = join(root, 'source')
    const bare = join(root, 'remote.git')
    await mkdir(source)
    await git(source, 'init', '--initial-branch=main')
    await git(source, 'commit', '--allow-empty', '-m', 'one')
    const first = await git(source, 'rev-parse', 'HEAD')
    await git(source, 'commit', '--allow-empty', '-m', 'two')
    await git(root, 'clone', '--bare', source, bare)
    await git(
      repo,
      '-c',
      'protocol.file.allow=always',
      'submodule',
      'add',
      '--name',
      'custom.name',
      bare,
      'folder/모듈 with spaces'
    )
    await git(repo, 'commit', '-m', 'module')
    const modulePath = join(repo, 'folder/모듈 with spaces')
    const expected = await git(modulePath, 'rev-parse', 'HEAD')
    expect(await invoke('git:submodules', 'repo')).toEqual([
      { path: 'folder/모듈 with spaces', url: bare, sha: expected, status: 'up-to-date' },
    ])
    await git(modulePath, 'checkout', '--detach', first)
    expect((await listSubmodules(repo))[0].status).toBe('out-of-date')
    await invoke('git:updateSubmodules', 'repo', { opId: 'sub-1' })
    expect((await listSubmodules(repo))[0].status).toBe('up-to-date')
    const events = mocks.broadcast.mock.calls.filter(([, payload]) => payload.opId === 'sub-1')
    expect(events[0][1].progress.value).toBe(0)
    expect(events.at(-1)?.[1].progress.value).toBe(1)
    expect(
      events.every(([, payload]) => payload.progress.value >= 0 && payload.progress.value <= 1)
    ).toBe(true)

    const destination = join(root, 'clone')
    await clone({ opId: 'clone', url: repo, path: destination })
    expect((await listSubmodules(destination))[0].status).toBe('uninitialized')
    // Enable local protocol for this test only; the application leaves Git's policy intact.
    vi.stubEnv('GIT_ALLOW_PROTOCOL', 'file')
    await updateSubmodules(destination)
    expect((await listSubmodules(destination))[0].status).toBe('up-to-date')
  })

  it('lists an empty repository without creating configuration', async () => {
    expect(await listSubmodules(repo)).toEqual([])
  })
})
