import { beforeEach, describe, expect, it, vi } from 'vitest'
import { HandlerError } from '@shared/errors'
import { AppFileStatusKind } from '@shared/models/status'
import { selectAll } from '@shared/models/diff-selection'

const mocks = vi.hoisted(() => ({
  handlers: new Map<string, (...args: unknown[]) => Promise<unknown>>(),
  repository: vi.fn(),
  status: vi.fn(),
  workingDiff: vi.fn(),
  commitDiff: vi.fn(),
  committedFile: vi.fn(),
  commit: vi.fn(),
  discard: vi.fn(),
}))
vi.mock('../../../src/main/ipc', () => ({
  handle: (name: string, callback: (...args: unknown[]) => Promise<unknown>) =>
    mocks.handlers.set(name, callback),
}))
vi.mock('../../../src/main/store/repositories', () => ({ getRepository: mocks.repository }))
vi.mock('../../../src/main/git/status', () => ({ getStatus: mocks.status }))
vi.mock('../../../src/main/git/diff', () => ({
  getWorkingDiff: mocks.workingDiff,
  getCommitDiff: mocks.commitDiff,
  getCommittedFile: mocks.committedFile,
}))
vi.mock('../../../src/main/git/apply', () => ({ discardLines: mocks.discard }))
vi.mock('../../../src/main/git/commit', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../../src/main/git/commit')>()
  return { ...actual, createCommit: mocks.commit }
})
import { register } from '../../../src/main/git/handlers/diff-commit'
import { GitError } from '../../../src/main/git/core'

const file = { path: 'file.txt', status: { kind: AppFileStatusKind.Modified } }
function invoke(channel: string, ...args: unknown[]) {
  return mocks.handlers.get(channel)!(null, 'repo-id', ...args)
}
beforeEach(() => {
  vi.resetAllMocks()
  mocks.handlers.clear()
  mocks.repository.mockReturnValue({ path: process.cwd() })
  mocks.status.mockResolvedValue({ files: [file] })
  register()
})
describe('diff/commit IPC handlers', () => {
  it('registers exactly the four assigned channels and gets working file from status', async () => {
    expect([...mocks.handlers.keys()].sort()).toEqual([
      'git:commit',
      'git:commitDiff',
      'git:discardLines',
      'git:workingDiff',
    ])
    mocks.workingDiff.mockResolvedValue({ kind: 'binary' })
    expect(await invoke('git:workingDiff', 'file.txt')).toEqual({ kind: 'binary' })
    expect(mocks.repository).toHaveBeenCalledWith('repo-id')
    expect(mocks.status).toHaveBeenCalledWith(process.cwd())
    expect(mocks.workingDiff).toHaveBeenCalledWith(process.cwd(), file)
  })
  it('gets committed metadata independently of G2 status/commitFiles', async () => {
    mocks.committedFile.mockResolvedValue(file)
    await invoke('git:commitDiff', 'sha', 'file.txt')
    expect(mocks.committedFile).toHaveBeenCalledWith(process.cwd(), 'sha', 'file.txt')
    expect(mocks.commitDiff).toHaveBeenCalledWith(process.cwd(), 'sha', file)
    expect(mocks.status).not.toHaveBeenCalled()
  })
  it('passes commit selections and returns the new SHA', async () => {
    const input = {
      summary: 'commit',
      files: [{ path: file.path, selection: selectAll() }],
      amend: true,
    }
    mocks.commit.mockResolvedValue('new-sha')
    expect(await invoke('git:commit', input)).toBe('new-sha')
    expect(mocks.commit).toHaveBeenCalledWith(process.cwd(), input, [file])
  })
  it('passes discard selections and reports missing paths', async () => {
    const selection = selectAll()
    await invoke('git:discardLines', file.path, selection)
    expect(mocks.discard).toHaveBeenCalledWith(process.cwd(), file, selection)
    await expect(invoke('git:workingDiff', 'missing')).rejects.toMatchObject({ kind: 'not-found' })
  })
  it('translates git failures to HandlerError', async () => {
    mocks.workingDiff.mockRejectedValue(
      new GitError(
        { stdout: '', stderr: 'git failed', exitCode: 1, gitError: null, path: process.cwd() },
        ['diff']
      )
    )
    await expect(invoke('git:workingDiff', file.path)).rejects.toBeInstanceOf(HandlerError)
    await expect(invoke('git:workingDiff', file.path)).rejects.toMatchObject({
      kind: 'unknown',
      detail: 'git failed',
    })
  })
})
