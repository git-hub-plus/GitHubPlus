// Ported from GitHub Desktop (MIT): app/test/unit/git/merge-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/stash-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/revert-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/reset-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/tag-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/cherry-pick-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/squash-test.ts
// Ported from GitHub Desktop (MIT): app/test/unit/git/reorder-test.ts
import { readFile, rm, access } from 'node:fs/promises'
import { join } from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
vi.mock('../../../../src/main/log', () => ({ log: { warn: vi.fn(), error: vi.fn() } }))
import { registerGitAuthProvider } from '../../../../src/main/git/core'
import { merge } from '../../../../src/main/git/merge'
import {
  resolveConflict,
  markResolved,
  continueOperation,
  abortOperation,
} from '../../../../src/main/git/conflicts'
import {
  stashList,
  stashCreate,
  stashFiles,
  stashDiff,
  stashApply,
  stashDrop,
} from '../../../../src/main/git/stash'
import { revert } from '../../../../src/main/git/revert'
import { undoLastCommit } from '../../../../src/main/git/reset'
import { getTags, createTag, deleteTag, pushTag } from '../../../../src/main/git/tag'
import { cherryPick } from '../../../../src/main/git/cherry-pick'
import { rebase } from '../../../../src/main/git/rebase'
import { squash } from '../../../../src/main/git/squash'
import { reorder } from '../../../../src/main/git/reorder'
import { getStatus } from '../../../../src/main/git/status'
import { repository, run, file, commit } from '../helpers'

let unregister: () => void
beforeEach(() => {
  unregister = registerGitAuthProvider(() => ({
    configArgs: [
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
    ],
    env: {
      GIT_CONFIG_NOSYSTEM: '1',
      GIT_CONFIG_GLOBAL: process.platform === 'win32' ? 'NUL' : '/dev/null',
    },
  }))
})
afterEach(() => unregister())

async function conflictRepository() {
  const root = await repository()
  for (const path of ['text', 'markers', 'deleted', 'binary'])
    await file(root, path, path === 'binary' ? 'base\0bytes' : 'base\n')
  await commit(root, 'base')
  await run(root, ['checkout', '-b', 'topic'])
  for (const path of ['text', 'markers', 'deleted', 'binary'])
    await file(root, path, path === 'binary' ? 'theirs\0bytes' : 'theirs\n')
  const theirs = await commit(root, 'theirs')
  await run(root, ['checkout', 'main'])
  for (const path of ['text', 'markers', 'binary'])
    await file(root, path, path === 'binary' ? 'ours\0bytes' : 'ours\n')
  await rm(join(root, 'deleted'))
  const ours = await commit(root, 'ours')
  return { root, ours, theirs }
}

describe('merge and manual conflict resolution', () => {
  it('merges, reports no-op, and supports squash merge without creating a commit', async () => {
    const root = await repository()
    await file(root, 'base')
    await commit(root, 'base')
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'topic')
    await commit(root, 'topic')
    await run(root, ['checkout', 'main'])
    const head = await run(root, ['rev-parse', 'HEAD'])
    expect(await merge(root, 'topic', { squash: true })).toBe('success')
    expect(await run(root, ['rev-parse', 'HEAD'])).toBe(head)
    await commit(root, 'squashed merge')
    expect(await merge(root, 'topic')).toBe('success')
    expect(await merge(root, 'topic')).toBe('nothing-to-do')
  })
  it('resolves text/binary/deletion conflicts and adds remaining markers unchanged', async () => {
    const { root } = await conflictRepository()
    expect(await merge(root, 'topic')).toBe('conflicts')
    expect((await getStatus(root)).inProgress?.kind).toBe('merge')
    expect(await continueOperation(root)).toBe('conflicts')
    await resolveConflict(root, 'text', 'theirs')
    await resolveConflict(root, 'binary', 'ours')
    await resolveConflict(root, 'deleted', 'ours')
    await expect(access(join(root, 'deleted'))).rejects.toThrow()
    await markResolved(root, ['markers'])
    expect(await continueOperation(root, { message: 'resolved merge' })).toBe('success')
    expect(await readFile(join(root, 'text'), 'utf8')).toBe('theirs\n')
    expect(await readFile(join(root, 'binary'), 'utf8')).toBe('ours\0bytes')
    expect(await readFile(join(root, 'markers'), 'utf8')).toContain('<<<<<<<')
    expect((await getStatus(root)).inProgress).toBeUndefined()
    expect((await run(root, ['rev-list', '--parents', '-n', '1', 'HEAD'])).split(' ')).toHaveLength(
      3
    )
  })
  it('retains the existing side of a deletion conflict and aborts back to HEAD', async () => {
    const { root, ours } = await conflictRepository()
    expect(await merge(root, 'topic')).toBe('conflicts')
    await resolveConflict(root, 'deleted', 'theirs')
    expect(await readFile(join(root, 'deleted'), 'utf8')).toBe('theirs\n')
    await abortOperation(root)
    expect(await run(root, ['rev-parse', 'HEAD'])).toBe(ours)
    expect((await getStatus(root)).files).toEqual([])
    expect(await continueOperation(root)).toBe('nothing-to-do')
    await expect(resolveConflict(root, 'text', 'ours')).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
    await expect(markResolved(root, ['../escape'])).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })
})

describe('stash including third-parent untracked files', () => {
  it('lists external stashes, reads tracked and untracked diffs, applies, pops and drops', async () => {
    const root = await repository()
    expect(await stashList(root)).toEqual([])
    await file(root, 'tracked')
    await commit(root, 'base')
    await file(root, 'tracked', 'stashed\n')
    await file(root, '새 파일 [1].txt', 'untracked stash\n')
    await stashCreate(root, { message: 'custom message', includeUntracked: true })
    const [entry] = await stashList(root)
    expect(entry).toMatchObject({
      name: 'stash@{0}',
      branchName: 'main',
      message: 'On main: custom message',
    })
    expect(entry.createdAt).toBeGreaterThan(0)
    expect((await stashFiles(root, entry.name)).map((f) => f.path).sort()).toEqual([
      'tracked',
      '새 파일 [1].txt',
    ])
    expect(await stashDiff(root, entry.name, 'tracked')).toMatchObject({
      kind: 'text',
      text: expect.stringContaining('+stashed'),
    })
    expect(await stashDiff(root, entry.name, '새 파일 [1].txt')).toMatchObject({
      kind: 'text',
      text: expect.stringContaining('+untracked stash'),
    })
    expect(await stashApply(root, entry.name)).toBe('success')
    expect(await stashList(root)).toHaveLength(1)
    await stashDrop(root, entry.name)
    await run(root, ['stash', 'push', '-u', '-m', 'external'])
    expect((await stashList(root))[0].message).toContain('external')
    expect(await stashApply(root, 'stash@{0}', { pop: true })).toBe('success')
    expect(await stashList(root)).toEqual([])
    await expect(stashDrop(root, '--all')).rejects.toMatchObject({ kind: 'invalid-argument' })
  })
  it('returns conflicts and preserves a conflicting pop entry', async () => {
    const root = await repository()
    await file(root, 'tracked', 'base\n')
    await commit(root, 'base')
    await file(root, 'tracked', 'stash\n')
    await stashCreate(root)
    await file(root, 'tracked', 'head\n')
    await commit(root, 'head')
    expect(await stashApply(root, 'stash@{0}', { pop: true })).toBe('conflicts')
    expect(await stashList(root)).toHaveLength(1)
    expect((await getStatus(root)).files[0].status.kind).toBe('Conflicted')
    await resolveConflict(root, 'tracked', 'theirs')
    expect((await getStatus(root)).files[0].status.kind).toBe('Modified')
  })
})

describe('revert, undo and tags', () => {
  it('reverts normal and merge commits with first-parent mainline', async () => {
    const root = await repository()
    await file(root, 'base')
    await commit(root, 'base')
    await file(root, 'normal')
    const normal = await commit(root, 'normal')
    expect(await revert(root, normal)).toBe('success')
    await expect(access(join(root, 'normal'))).rejects.toThrow()
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'topic')
    await commit(root, 'topic')
    await run(root, ['checkout', 'main'])
    await run(root, ['merge', '--no-ff', '-m', 'merge', 'topic'])
    expect(await revert(root, 'HEAD')).toBe('success')
    await expect(access(join(root, 'topic'))).rejects.toThrow()
  })
  it('continues and aborts conflicting reverts', async () => {
    const root = await repository()
    await file(root, 'text', 'base\n')
    await commit(root, 'base')
    await file(root, 'text', 'second\n')
    const sha = await commit(root, 'second')
    await file(root, 'text', 'third\n')
    await commit(root, 'third')
    expect(await revert(root, sha)).toBe('conflicts')
    expect((await getStatus(root)).inProgress?.kind).toBe('revert')
    await abortOperation(root)
    expect(await revert(root, sha)).toBe('conflicts')
    await resolveConflict(root, 'text', 'theirs')
    expect(await continueOperation(root)).toBe('success')
  })
  it('undoes the first and later commits, returns summary/body, rejects published HEAD', async () => {
    const root = await repository()
    await file(root, 'first')
    await commit(root, 'first\n\nbody')
    expect(await undoLastCommit(root)).toEqual({ summary: 'first', description: 'body' })
    expect((await getStatus(root)).headSha).toBeUndefined()
    expect((await getStatus(root)).files).toHaveLength(1)
    const first = await commit(root, 'first')
    await file(root, 'second')
    await commit(root, 'second')
    expect(await undoLastCommit(root)).toEqual({ summary: 'second', description: '' })
    expect(await run(root, ['rev-parse', 'HEAD'])).toBe(first)
    await commit(root, 'second')
    const remoteRoot = await repository()
    const remote = join(remoteRoot, 'remote.git')
    await run(remoteRoot, ['init', '--bare', remote])
    await run(root, ['remote', 'add', 'origin', remote])
    await run(root, ['push', '-u', 'origin', 'main'])
    const head = await run(root, ['rev-parse', 'HEAD'])
    await expect(undoLastCommit(root)).rejects.toMatchObject({ kind: 'invalid-argument' })
    expect(await run(root, ['rev-parse', 'HEAD'])).toBe(head)
  })
  it('creates lightweight/annotated tags, pushes with progress and deletes locally/remotely', async () => {
    const root = await repository()
    await file(root, 'base')
    const sha = await commit(root, 'base')
    expect(await getTags(root)).toEqual([])
    await createTag(root, { name: 'light', sha })
    await createTag(root, { name: 'annotated', sha, message: 'release body' })
    expect(await run(root, ['cat-file', '-t', 'light'])).toBe('commit')
    expect(await run(root, ['cat-file', '-t', 'annotated'])).toBe('tag')
    expect(await getTags(root)).toEqual([
      { name: 'annotated', targetSha: sha },
      { name: 'light', targetSha: sha },
    ])
    const remoteRoot = await repository()
    const remote = join(remoteRoot, 'remote.git')
    await run(remoteRoot, ['init', '--bare', remote])
    await run(root, ['remote', 'add', 'origin', remote])
    const values: number[] = []
    await pushTag(root, 'annotated', {}, (progress) => values.push(progress.value))
    expect(values[0]).toBe(0)
    expect(values.at(-1)).toBe(1)
    expect(await run(remote, ['rev-parse', 'refs/tags/annotated^{}'])).toBe(sha)
    await deleteTag(root, 'annotated', { remote: 'origin' })
    expect(await run(remote, ['show-ref', '--tags'], [1])).toBe('')
    await deleteTag(root, 'light')
    expect(await getTags(root)).toEqual([])
    await expect(createTag(root, { name: '--force', sha })).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })
})

describe('history editing using noninteractive rebase', () => {
  it('cherry-picks multiple commits and continues a conflict through the rest', async () => {
    const root = await repository()
    await file(root, 'text', 'base\n')
    await commit(root, 'base')
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'text', 'theirs\n')
    const a = await commit(root, 'a')
    await file(root, 'b')
    const b = await commit(root, 'b')
    await run(root, ['checkout', 'main'])
    await file(root, 'text', 'ours\n')
    await commit(root, 'ours')
    expect(await cherryPick(root, [a, b])).toBe('conflicts')
    expect((await getStatus(root)).inProgress?.kind).toBe('cherry-pick')
    await resolveConflict(root, 'text', 'theirs')
    expect(await continueOperation(root)).toBe('success')
    expect(await run(root, ['log', '-2', '--format=%s'])).toBe('b\na')
    expect((await getStatus(root)).inProgress).toBeUndefined()
    expect(await cherryPick(root, [])).toBe('nothing-to-do')
  })
  it('rebases a diverged branch, reports progress and rejects merge commits in replay range', async () => {
    const root = await repository()
    await file(root, 'base')
    await commit(root, 'base')
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'topic')
    await commit(root, 'topic')
    await run(root, ['checkout', 'main'])
    await file(root, 'main')
    const base = await commit(root, 'main')
    await run(root, ['checkout', 'topic'])
    const values: number[] = []
    expect(await rebase(root, 'main', (p) => values.push(p.value))).toBe('success')
    expect(await run(root, ['rev-parse', 'HEAD^'])).toBe(base)
    expect(await rebase(root, 'main')).toBe('nothing-to-do')
    expect(values[0]).toBe(0)
    expect(values.at(-1)).toBe(1)
    await run(root, ['checkout', 'main'])
    await run(root, ['merge', '--no-ff', '-m', 'merge', 'topic'])
    await expect(rebase(root, 'HEAD~2')).rejects.toMatchObject({ kind: 'invalid-argument' })
    await expect(cherryPick(root, ['HEAD'])).rejects.toMatchObject({ kind: 'invalid-argument' })
    await expect(squash(root, { shas: ['HEAD^', 'HEAD'], message: 'no' })).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })
  it('rebases with conflicts, aborts safely, then resolves and continues', async () => {
    const { root, ours } = await conflictRepository()
    expect(await rebase(root, 'topic')).toBe('conflicts')
    expect((await getStatus(root)).inProgress?.kind).toBe('rebase')
    await abortOperation(root)
    expect(await run(root, ['rev-parse', 'HEAD'])).toBe(ours)
    expect(await rebase(root, 'topic')).toBe('conflicts')
    for (const path of ['text', 'markers', 'deleted', 'binary'])
      await resolveConflict(root, path, 'theirs')
    expect(await continueOperation(root)).toBe('success')
    expect((await getStatus(root)).inProgress).toBeUndefined()
    await expect(access(join(root, '.git/ghp-advanced-rebase'))).rejects.toThrow()
  })
  it('squashes three commits into one with summary/body, including root and published commits', async () => {
    const root = await repository()
    const shas: string[] = []
    for (const name of ['a', 'b', 'c']) {
      await file(root, name)
      shas.push(await commit(root, name))
    }
    await run(root, ['update-ref', 'refs/remotes/origin/main', shas[2]])
    expect(await squash(root, { shas, message: 'combined\n\ncombined body' })).toBe('success')
    expect(await run(root, ['rev-list', '--count', 'HEAD'])).toBe('1')
    expect(await run(root, ['log', '-1', '--format=%B'])).toBe('combined\n\ncombined body')
    expect((await getStatus(root)).files).toEqual([])
  })
  it('reorders commits after a destination, then moves a commit to the root position', async () => {
    const root = await repository()
    const shas: string[] = []
    for (const name of ['a', 'b', 'c', 'd']) {
      await file(root, name)
      shas.push(await commit(root, name))
    }
    expect(await reorder(root, { shas: [shas[1]], afterSha: shas[3] })).toBe('success')
    expect(await run(root, ['log', '--reverse', '--format=%s'])).toBe('a\nc\nd\nb')
    expect(await reorder(root, { shas: ['HEAD'], afterSha: null })).toBe('success')
    expect(await run(root, ['log', '--reverse', '--format=%s'])).toBe('b\na\nc\nd')
    expect(await reorder(root, { shas: ['HEAD'], afterSha: 'HEAD^' })).toBe('nothing-to-do')
    await expect(reorder(root, { shas: ['HEAD'], afterSha: 'HEAD' })).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })
  it('preserves the custom squash message through fixup conflicts and later pick messages', async () => {
    const root = await repository()
    await file(root, 'text', 'base\n')
    await commit(root, 'base')
    await file(root, 'a')
    const a = await commit(root, 'a')
    await file(root, 'text', 'b\n')
    await commit(root, 'b')
    await file(root, 'text', 'c\n')
    const c = await commit(root, 'c')
    expect(await squash(root, { shas: [a, c], message: 'combined\n\nbody' })).toBe('conflicts')
    await resolveConflict(root, 'text', 'theirs')
    expect(await continueOperation(root)).toBe('conflicts')
    await resolveConflict(root, 'text', 'theirs')
    expect(await continueOperation(root)).toBe('success')
    expect(await run(root, ['log', '--reverse', '--format=%s'])).toBe('base\ncombined\nb')
    expect(await run(root, ['log', '-1', '--format=%B', 'HEAD^'])).toBe('combined\n\nbody')
    await expect(access(join(root, '.git/ghp-advanced-rebase'))).rejects.toThrow()
  })
})
