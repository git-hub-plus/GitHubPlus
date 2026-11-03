import { afterEach, describe, expect, it, vi } from 'vitest'
import type { IpcChannel, IpcContract } from '@shared/ipc'
import { HandlerError } from '@shared/errors'
import { registerGitAuthProvider } from '../../../../src/main/git/core'
import { register } from '../../../../src/main/git/handlers/advanced'
import { repository, file, commit, run } from '../helpers'

const mocks = vi.hoisted(() => ({
  handlers: new Map<string, (...args: unknown[]) => Promise<unknown>>(),
  broadcast: vi.fn(),
  path: '',
}))
vi.mock('../../../../src/main/log', () => ({ log: { warn: vi.fn(), error: vi.fn() } }))
vi.mock('../../../../src/main/ipc', () => ({
  handle: (name: string, callback: (...args: unknown[]) => Promise<unknown>) =>
    mocks.handlers.set(name, callback),
  broadcast: mocks.broadcast,
}))
vi.mock('../../../../src/main/store/repositories', () => ({
  getRepository: (id: string) => {
    if (id !== 'known') throw new HandlerError('not-found', 'Unknown repository')
    return { path: mocks.path }
  },
}))

function invoke<C extends IpcChannel>(channel: C, ...args: Parameters<IpcContract[C]>) {
  return mocks.handlers.get(channel)!(null, ...args) as Promise<ReturnType<IpcContract[C]>>
}
afterEach(() => {
  mocks.handlers.clear()
  mocks.broadcast.mockClear()
})

describe('advanced IPC registration', () => {
  it('registers exactly the 21 N4 channels and resolves repository IDs', async () => {
    register()
    expect([...mocks.handlers.keys()].sort()).toEqual(
      [
        'abortOperation',
        'cherryPick',
        'continueOperation',
        'createTag',
        'deleteTag',
        'markResolved',
        'merge',
        'pushTag',
        'rebase',
        'reorder',
        'resolveConflict',
        'revert',
        'squash',
        'stashApply',
        'stashCreate',
        'stashDiff',
        'stashDrop',
        'stashFiles',
        'stashList',
        'tags',
        'undoLastCommit',
      ]
        .map((name) => `git:${name}`)
        .sort()
    )
    await expect(invoke('git:tags', 'unknown')).rejects.toMatchObject({ kind: 'not-found' })
    mocks.path = await repository()
    await file(mocks.path, 'base')
    await commit(mocks.path, 'base')
    expect(await invoke('git:tags', 'known')).toEqual([])
    await invoke('git:createTag', 'known', { name: 'v1', sha: 'HEAD' })
    expect(await invoke('git:tags', 'known')).toHaveLength(1)
    await expect(
      invoke('git:createTag', 'known', { name: 'v1', sha: 'HEAD' })
    ).rejects.toBeInstanceOf(HandlerError)
    await invoke('git:deleteTag', 'known', 'v1')
  })
  it('sends push progress with the caller opId, without altering the contract', async () => {
    register()
    mocks.path = await repository()
    await file(mocks.path, 'base')
    await commit(mocks.path, 'base')
    await invoke('git:createTag', 'known', { name: 'v1', sha: 'HEAD' })
    const remote = await repository()
    await run(remote, ['init', '--bare', 'remote.git'])
    await run(mocks.path, ['remote', 'add', 'test', `${remote}/remote.git`])
    await invoke('git:pushTag', 'known', 'v1', { opId: 'tag-push', remote: 'test' })
    expect(mocks.broadcast).toHaveBeenLastCalledWith('git:progress', {
      opId: 'tag-push',
      progress: { kind: 'push', title: 'Pushing tag', value: 1 },
    })
  })
  it('sends rebase progress and returns conflicts through IPC', async () => {
    const unregister = registerGitAuthProvider(() => ({
      configArgs: [
        '-c',
        'user.name=Test',
        '-c',
        'user.email=test@example.com',
        '-c',
        'commit.gpgsign=false',
      ],
    }))
    try {
      register()
      mocks.path = await repository()
      await file(mocks.path, 'text', 'base\n')
      await commit(mocks.path, 'base')
      await run(mocks.path, ['checkout', '-b', 'topic'])
      await file(mocks.path, 'text', 'theirs\n')
      await commit(mocks.path, 'theirs')
      await run(mocks.path, ['checkout', 'main'])
      await file(mocks.path, 'text', 'ours\n')
      await commit(mocks.path, 'ours')
      expect(await invoke('git:rebase', 'known', 'topic', { opId: 'rebase-op' })).toBe('conflicts')
      expect(mocks.broadcast).toHaveBeenCalledWith('git:progress', {
        opId: 'rebase-op',
        progress: { kind: 'generic', title: 'Rebasing', value: 0 },
      })
      await invoke('git:abortOperation', 'known')
    } finally {
      unregister()
    }
  })
})
