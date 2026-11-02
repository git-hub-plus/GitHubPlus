// Ported from GitHub Desktop (MIT): app/test/unit/git/branch-test.ts,
// checkout-test.ts, remote-test.ts, push-test.ts and pull/pull-test.ts (N1 scenarios).
import { mkdtemp, mkdir, rm, writeFile, readFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join, resolve, sep } from 'node:path'
import { exec } from 'dugite'
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest'
import type { IpcChannel, IpcContract } from '../../../src/shared/ipc'
import type { GitProgress } from '../../../src/shared/models/git'

const mocks = vi.hoisted(() => ({
  handlers: new Map<string, (...args: unknown[]) => unknown>(),
  broadcast: vi.fn(),
  userData: '',
}))
vi.mock('../../../src/main/ipc', () => ({
  handle: (channel: string, handler: (...args: unknown[]) => unknown) =>
    mocks.handlers.set(channel, handler),
  broadcast: mocks.broadcast,
}))
vi.mock('electron', () => ({ app: { getPath: () => mocks.userData } }))
vi.mock('../../../src/main/log', () => ({ log: { warn: vi.fn(), error: vi.fn() } }))

import { register } from '../../../src/main/git/handlers/branches-sync'
import {
  loadRepositories,
  addRepository,
  listRepositories,
} from '../../../src/main/store/repositories'
import { getBranches } from '../../../src/main/git/for-each-ref'
import { createBranch, renameBranch, deleteBranch } from '../../../src/main/git/branch'
import { checkoutBranch } from '../../../src/main/git/checkout'
import { getRemotes } from '../../../src/main/git/remote'
import { pull } from '../../../src/main/git/pull'
import { push } from '../../../src/main/git/push'
import { clone } from '../../../src/main/git/clone'
import { withGitErrors } from '../../../src/main/git/core'
import { progressStream } from '../../../src/main/git/progress/from-process'

let root: string
let repo: string
let bare: string

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
    path,
    {
      env: {
        GIT_CONFIG_NOSYSTEM: '1',
        GIT_CONFIG_GLOBAL: '',
        GIT_TERMINAL_PROMPT: '0',
        LC_ALL: 'C',
      },
    }
  )
  if (result.exitCode !== 0) throw new Error(result.stderr)
  return result.stdout.trim()
}

async function commit(path: string, file: string, content: string): Promise<string> {
  await writeFile(join(path, file), content)
  await git(path, 'add', '--', file)
  await git(path, 'commit', '-m', content)
  return git(path, 'rev-parse', 'HEAD')
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
  root = await mkdtemp(join(tmpdir(), 'ghp-g3-'))
  mocks.userData = join(root, 'user-data')
  await mkdir(mocks.userData)
  repo = join(root, 'repo')
  bare = join(root, 'remote.git')
  await mkdir(repo)
  await git(root, 'init', '--bare', '--initial-branch=main', bare)
  await git(repo, 'init', '--initial-branch=main')
  await git(repo, 'config', 'user.name', 'Test')
  await git(repo, 'config', 'user.email', 'test@example.com')
  await git(repo, 'config', 'commit.gpgsign', 'false')
  await git(repo, 'remote', 'add', 'origin', bare)
  await commit(repo, 'readme.txt', 'initial')
  await loadRepositories()
  mocks.handlers.clear()
  mocks.broadcast.mockClear()
  register()
})

afterEach(async () => {
  vi.unstubAllEnvs()
  // Only remove the exact generated temporary directory, never a computed parent.
  const target = resolve(root)
  if (
    !target.startsWith(resolve(tmpdir()) + sep) ||
    !target.split(sep).at(-1)?.startsWith('ghp-g3-')
  )
    throw new Error('Unsafe cleanup path')
  await rm(target, { recursive: true, force: true, maxRetries: 5, retryDelay: 100 })
})

describe('branch and sync IPC', () => {
  it('registers every G3 channel and handles branch lifecycle, metadata and duplicate errors', async () => {
    expect(mocks.handlers.size).toBe(10)
    const info = await addRepository(repo)
    await invoke('git:createBranch', info.id, { name: 'feature/nested', checkout: true })
    const branches = await invoke('git:branches', info.id)
    expect(branches.find((branch) => branch.name === 'feature/nested')).toMatchObject({
      type: 'local',
      isCurrent: true,
      tipSha: await git(repo, 'rev-parse', 'HEAD'),
    })
    expect(branches[0].tipDate).toBeGreaterThan(0)
    await expect(
      invoke('git:createBranch', info.id, { name: 'feature/nested' })
    ).rejects.toMatchObject({ kind: 'branch-exists' })
    await invoke('git:renameBranch', info.id, 'feature/nested', 'renamed')
    await invoke('git:checkout', info.id, 'main', { opId: 'checkout-1' })
    await invoke('git:deleteBranch', info.id, 'renamed')
    expect((await getBranches(repo)).map((branch) => branch.name)).toEqual(['main'])
    expect(mocks.broadcast).toHaveBeenCalledWith(
      'git:progress',
      expect.objectContaining({
        opId: 'checkout-1',
        progress: expect.objectContaining({ value: 1 }),
      })
    )
    expect(await invoke('git:remotes', info.id)).toEqual([{ name: 'origin', url: bare }])
  })

  it('creates explicit tracking branches for remote selections and excludes symbolic HEAD', async () => {
    await push(repo, { setUpstream: true })
    await createBranch(repo, { name: 'feature/nested', checkout: true })
    await push(repo, { setUpstream: true })
    const other = join(root, 'other')
    await clone({ opId: 'clone', url: bare, path: other })
    expect((await getBranches(other)).some((branch) => branch.name === 'origin/HEAD')).toBe(false)
    await git(other, 'config', 'branch.autoSetupMerge', 'false')
    await checkoutBranch(other, 'origin/feature/nested')
    expect((await getBranches(other)).find((branch) => branch.isCurrent)).toMatchObject({
      name: 'feature/nested',
      upstream: 'origin/feature/nested',
      type: 'local',
    })
    await checkoutBranch(other, 'main')
    await expect(
      withGitErrors(() => checkoutBranch(other, 'origin/feature/nested'))
    ).rejects.toMatchObject({ kind: 'branch-exists' })
  })

  it('reports checkout conflicts without discarding local changes', async () => {
    await createBranch(repo, { name: 'feature', checkout: true })
    await commit(repo, 'readme.txt', 'feature content')
    await checkoutBranch(repo, 'main')
    await writeFile(join(repo, 'readme.txt'), 'dirty')
    await expect(withGitErrors(() => checkoutBranch(repo, 'feature'))).rejects.toMatchObject({
      kind: 'local-changes-overwritten',
    })
    expect(await readFile(join(repo, 'readme.txt'), 'utf8')).toBe('dirty')
  })

  it('creates at a start point without tracking and safely handles rename collisions and case changes', async () => {
    await push(repo, { setUpstream: true })
    const tip = await git(repo, 'rev-parse', 'HEAD')
    await createBranch(repo, { name: 'Feature', startPoint: 'origin/main' })
    expect((await getBranches(repo)).find((branch) => branch.name === 'Feature')).toMatchObject({
      tipSha: tip,
      upstream: undefined,
      isCurrent: false,
    })
    await renameBranch(repo, 'Feature', 'FEATURE')
    await expect(withGitErrors(() => renameBranch(repo, 'FEATURE', 'main'))).rejects.toMatchObject({
      kind: 'branch-exists',
    })
    expect(
      (await getBranches(repo))
        .filter((branch) => branch.type === 'local')
        .map((branch) => branch.name)
    ).toEqual(['FEATURE', 'main'])
    await expect(createBranch(repo, { name: 'invalid name' })).rejects.toThrow()
  })

  it('does not register a failed clone or finish its progress', async () => {
    await expect(
      invoke('git:clone', {
        opId: 'failed-clone',
        url: join(root, 'missing.git'),
        path: join(root, 'failed'),
      })
    ).rejects.toThrow()
    expect(listRepositories()).toEqual([])
    expect(
      mocks.broadcast.mock.calls.some(
        ([, payload]) => payload.opId === 'failed-clone' && payload.progress.value === 1
      )
    ).toBe(false)
  })

  it('pushes first upstream, clones and registers, fetches, rejects stale push and pulls', async () => {
    const info = await addRepository(repo)
    await expect(invoke('git:push', info.id, { opId: 'no-upstream' })).rejects.toMatchObject({
      kind: 'no-upstream',
    })
    await invoke('git:push', info.id, { opId: 'push-1', setUpstream: true })
    const other = await invoke('git:clone', {
      opId: 'clone-1',
      url: bare,
      path: join(root, 'nested', 'clone'),
      branch: 'main',
    })
    expect(listRepositories()).toContainEqual(other)
    expect(other.path).toBe(join(root, 'nested', 'clone'))
    const sha = await commit(other.path, 'other.txt', 'remote commit')
    await invoke('git:push', other.id, { opId: 'push-2' })
    await invoke('git:fetch', info.id, { opId: 'fetch-1', remote: 'origin' })
    expect((await getBranches(repo)).find((branch) => branch.name === 'origin/main')?.tipSha).toBe(
      sha
    )
    await expect(invoke('git:push', info.id, { opId: 'stale-push' })).rejects.toMatchObject({
      kind: 'push-needs-pull',
    })
    await invoke('git:pull', info.id, { opId: 'pull-1' })
    expect(await git(repo, 'rev-parse', 'HEAD')).toBe(sha)
    for (const opId of ['push-1', 'clone-1', 'fetch-1', 'pull-1']) {
      const events = mocks.broadcast.mock.calls.filter(([, payload]) => payload.opId === opId)
      expect(events.length).toBeGreaterThanOrEqual(2)
      expect(events.at(-1)?.[1].progress.value).toBe(1)
      expect(
        events.every(([, payload]) => payload.progress.value >= 0 && payload.progress.value <= 1)
      ).toBe(true)
    }
  })

  it('uses merge by default and honors configured pull rebase', async () => {
    await push(repo, { setUpstream: true })
    const other = join(root, 'other')
    await clone({ opId: 'clone', url: bare, path: other })
    await commit(other, 'remote.txt', 'remote')
    await push(other, {})
    await commit(repo, 'local.txt', 'local')
    await pull(repo)
    expect((await git(repo, 'rev-list', '--parents', '-n', '1', 'HEAD')).split(' ')).toHaveLength(3)
    await push(repo, {})
    await git(other, 'config', 'user.name', 'Test')
    await git(other, 'config', 'user.email', 'test@example.com')
    await git(other, 'config', 'commit.gpgsign', 'false')
    await git(other, 'config', 'pull.rebase', 'true')
    await commit(other, 'rebased.txt', 'rebased')
    await pull(other)
    expect((await git(other, 'rev-list', '--parents', '-n', '1', 'HEAD')).split(' ')).toHaveLength(
      2
    )
    expect(await readFile(join(other, 'local.txt'), 'utf8')).toBe('local')
  })

  it('distinguishes remote hook rejection from a stale push', async () => {
    await push(repo, { setUpstream: true })
    await git(bare, 'config', 'receive.denyNonFastForwards', 'true')
    await writeFile(
      join(bare, 'hooks', 'pre-receive'),
      '#!/bin/sh\necho policy-rejected >&2\nexit 1\n'
    )
    await commit(repo, 'new.txt', 'new')
    await expect(withGitErrors(() => push(repo, {}))).rejects.toMatchObject({
      kind: 'push-rejected',
    })
  })

  it('supports safe versus forced deletion and deletes remote branches', async () => {
    await push(repo, { setUpstream: true })
    await createBranch(repo, { name: 'remove-me', checkout: true })
    await commit(repo, 'new.txt', 'unmerged')
    await checkoutBranch(repo, 'main')
    await expect(deleteBranch(repo, 'remove-me')).rejects.toThrow()
    await deleteBranch(repo, 'remove-me', { force: true })
    await createBranch(repo, { name: 'remote-only' })
    await push(repo, { branch: 'remote-only', setUpstream: true })
    await deleteBranch(repo, 'origin/remote-only', { deleteRemote: true })
    expect(await git(bare, 'branch', '--list', 'remote-only')).toBe('')
    expect((await getBranches(repo)).some((branch) => branch.name === 'origin/remote-only')).toBe(
      false
    )
  })

  it('lists sorted remotes with rewritten URLs and preserves URL whitespace', async () => {
    await git(repo, 'config', 'url.https://example.com/.insteadOf', 'example:')
    await git(repo, 'remote', 'add', 'aaa', 'example:project with spaces ')
    expect(await getRemotes(repo)).toEqual([
      { name: 'aaa', url: 'https://example.com/project with spaces ' },
      { name: 'origin', url: bare },
    ])
  })
})

describe('stderr progress stream', () => {
  it.each(['clone', 'fetch', 'pull', 'push', 'checkout'] as const)(
    'parses %s fragmented CR/LF output in range',
    (kind) => {
      const events: GitProgress[] = []
      const stream = progressStream(kind, 'operation', (event) => events.push(event))
      const text =
        kind === 'push'
          ? 'Writing objects: 50% (5/10)\rWriting objects: 100% (10/10), done.'
          : kind === 'checkout'
            ? 'Checking out files: 50% (5/10)\rChecking out files: 100% (10/10), done.'
            : 'Receiving objects: 50% (5/10)\rReceiving objects: 100% (10/10), done.'
      const bytes = Buffer.from(text)
      for (let offset = 0; offset < bytes.length; offset += 7)
        stream.write(bytes.subarray(offset, offset + 7))
      stream.end()
      expect(events).toHaveLength(2)
      expect(
        events.every((event) => event.kind === kind && event.value >= 0 && event.value <= 1)
      ).toBe(true)
      expect(events[1].value).toBeGreaterThan(events[0].value)
    }
  )
})
