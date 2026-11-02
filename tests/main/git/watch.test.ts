import { setTimeout as delay } from 'node:timers/promises'
import { join } from 'node:path'
import { describe, expect, it, vi } from 'vitest'
import {
  createRepositoryWatcher,
  watchRepository,
  stopWatchingRepository,
} from '../../../src/main/watch'
import { commit, file, repository, run } from './helpers'

const connected = vi.hoisted(() => ({ paths: new Map<string, string>(), broadcast: vi.fn() }))
vi.mock('../../../src/main/store/repositories', () => ({
  getRepository: (id: string) => ({ path: connected.paths.get(id) }),
}))
vi.mock('../../../src/main/ipc', () => ({ broadcast: connected.broadcast }))

describe('repository watching', () => {
  it('switches the selected repository, cancels pending events and broadcasts only the active id', async () => {
    const first = await repository()
    const second = await repository()
    connected.paths.set('first', first)
    connected.paths.set('second', second)
    connected.broadcast.mockClear()
    try {
      await watchRepository('first')
      await file(first, 'pending')
      await watchRepository('second')
      await file(first, 'old-repository')
      await file(second, 'active-repository')
      await delay(650)
      expect(connected.broadcast.mock.calls).toEqual([['git:repoChanged', { repoId: 'second' }]])
    } finally {
      stopWatchingRepository()
      connected.paths.clear()
    }
  })
  it('debounces worktree changes once, ignores objects and stops cleanly', async () => {
    const root = await repository()
    await file(root, 'file')
    await commit(root, 'base')
    const changed = vi.fn()
    const stop = await createRepositoryWatcher(root, changed, { debounceMs: 100 })
    try {
      await file(root, 'file', 'one')
      await file(root, 'file', 'two')
      await file(root, 'new')
      await delay(400)
      expect(changed).toHaveBeenCalledTimes(1)
      changed.mockClear()
      await file(root, '.git/objects/noise', 'object noise')
      await delay(300)
      expect(changed).not.toHaveBeenCalled()
    } finally {
      stop()
    }
    await file(root, 'after-stop')
    await delay(300)
    expect(changed).not.toHaveBeenCalled()
  })
  it('observes HEAD, refs and index, including newly created refs', async () => {
    const root = await repository()
    await file(root, 'file')
    const sha = await commit(root, 'base')
    // Created before watching so only the index write is observed below.
    await file(root, 'staged')
    const changed = vi.fn()
    const stop = await createRepositoryWatcher(root, changed, { debounceMs: 100 })
    try {
      for (const operation of [
        () => file(root, '.git/refs/heads/new/nested', sha + '\n'),
        () => file(root, '.git/HEAD', 'ref: refs/heads/main\n'),
        // `update-index --refresh` skips writing an up-to-date index, so stage a file instead.
        () => run(root, ['add', 'staged']),
      ]) {
        changed.mockClear()
        await operation()
        await delay(400)
        expect(changed).toHaveBeenCalled()
      }
    } finally {
      stop()
    }
  })
  it('observes shared refs and per-worktree HEAD in a linked worktree', async () => {
    const root = await repository()
    await file(root, 'file')
    await commit(root, 'base')
    const linked = join(root, 'linked')
    await run(root, ['worktree', 'add', '-b', 'linked', linked])
    const changed = vi.fn()
    const stop = await createRepositoryWatcher(linked, changed, { debounceMs: 100 })
    try {
      await run(root, ['branch', 'shared-ref'])
      await delay(400)
      expect(changed).toHaveBeenCalledTimes(1)
      changed.mockClear()
      await file(linked, 'file', 'changed')
      await delay(400)
      expect(changed).toHaveBeenCalledTimes(1)
    } finally {
      stop()
    }
  })
})
