import { readFile, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { describe, expect, it, vi } from 'vitest'
import { discardFiles } from '../../../src/main/git/discard'
import { getStatus } from '../../../src/main/git/status'
import { commit, file, repository, run } from './helpers'

describe('discard whole files', () => {
  it('restores staged and unstaged tracked changes and trashes untracked and added files', async () => {
    const root = await repository()
    await file(root, 'tracked')
    await file(root, 'deleted')
    await commit(root, 'base')
    await file(root, 'tracked', 'staged\n')
    await run(root, ['add', 'tracked'])
    await file(root, 'tracked', 'unstaged\n')
    await rm(join(root, 'deleted'))
    await file(root, 'untracked')
    await file(root, 'added')
    await run(root, ['add', 'added'])
    const trash = vi.fn(async (path: string) => {
      await rm(path)
    })
    await discardFiles(root, ['tracked', 'deleted', 'untracked', 'added'], trash)
    expect(await readFile(join(root, 'tracked'), 'utf8')).toBe('original\n')
    expect(await readFile(join(root, 'deleted'), 'utf8')).toBe('original\n')
    expect(trash.mock.calls.map(([path]) => path)).toEqual([
      join(root, 'untracked'),
      join(root, 'added'),
    ])
    expect((await getStatus(root)).files).toEqual([])
  })
  it('restores rename sources, removes staged destinations, and leaves unselected files alone', async () => {
    const root = await repository()
    await file(root, 'old')
    await file(root, 'keep')
    await commit(root, 'base')
    await run(root, ['mv', 'old', 'new'])
    await file(root, 'keep', 'keep this\n')
    await discardFiles(root, ['new'], async (path) => {
      await rm(path)
    })
    expect(await readFile(join(root, 'old'), 'utf8')).toBe('original\n')
    expect((await getStatus(root)).files.map((f) => f.path)).toEqual(['keep'])
  })
  it('does not change files or index when trash fails', async () => {
    const root = await repository()
    await file(root, 'initial')
    await commit(root, 'base')
    await file(root, 'added')
    await run(root, ['add', 'added'])
    await expect(
      discardFiles(root, ['added'], async () => {
        throw new Error('trash failed')
      })
    ).rejects.toThrow('trash failed')
    expect(await readFile(join(root, 'added'), 'utf8')).toBe('original\n')
    expect(await run(root, ['diff', '--cached', '--name-only'])).toBe('added')
  })
  it('handles added files on unborn HEAD and rejects traversal, directories and git metadata', async () => {
    const root = await repository()
    await file(root, 'new')
    await run(root, ['add', 'new'])
    const trash = vi.fn(async (path: string) => {
      await rm(path)
    })
    for (const path of ['../outside', '.', '.git/HEAD'])
      await expect(discardFiles(root, [path], trash)).rejects.toThrow()
    expect(trash).not.toHaveBeenCalled()
    await discardFiles(root, ['new'], trash)
    expect((await getStatus(root)).files).toEqual([])
  })
  it('restores files in a removed directory and treats wildcard characters literally', async () => {
    const root = await repository()
    await file(root, 'nested/deleted')
    await file(root, '[abc].txt')
    await file(root, 'a.txt')
    await commit(root, 'base')
    await rm(join(root, 'nested'), { recursive: true })
    await file(root, '[abc].txt', 'changed')
    await file(root, 'a.txt', 'keep')
    await discardFiles(root, ['nested/deleted', '[abc].txt'])
    expect(await readFile(join(root, 'nested/deleted'), 'utf8')).toBe('original\n')
    expect(await readFile(join(root, '[abc].txt'), 'utf8')).toBe('original\n')
    expect(await readFile(join(root, 'a.txt'), 'utf8')).toBe('keep')
  })
  it('trashes a conflicted file absent from HEAD and restores a conflicted tracked file', async () => {
    const root = await repository()
    await file(root, 'tracked')
    await file(root, 'removed')
    await commit(root, 'base')
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'added', 'theirs')
    await file(root, 'tracked', 'theirs')
    await file(root, 'removed', 'theirs')
    await commit(root, 'theirs')
    await run(root, ['checkout', 'main'])
    await file(root, 'added', 'ours')
    await file(root, 'tracked', 'ours')
    await rm(join(root, 'removed'))
    await commit(root, 'ours')
    await run(root, ['merge', 'topic'], [1])
    const trash = vi.fn(async (path: string) => {
      await rm(path)
    })
    await discardFiles(root, ['added', 'tracked', 'removed'], trash)
    // Both files exist in HEAD, including an add/add conflict.
    expect(trash.mock.calls).toEqual([[join(root, 'removed')]])
    expect(await readFile(join(root, 'added'), 'utf8')).toBe('ours')
    expect(await readFile(join(root, 'tracked'), 'utf8')).toBe('ours')
    expect((await getStatus(root)).files).toEqual([])
  })
})
