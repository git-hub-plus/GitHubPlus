// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { GhpApi, IpcResult } from '@shared/ipc'
import type { Commit, CommittedFile } from '@shared/models/git'
import type { FileDiff } from '@shared/models/diff'
import { AppFileStatusKind } from '@shared/models/status'
import { setLanguage } from '@shared/i18n'
import { relativeTime } from '../../../src/renderer/src/lib/relative-time'
import { useHistoryStore } from '../../../src/renderer/src/state/history-store'

function deferred<T>() {
  let resolve!: (value: IpcResult<T>) => void
  const promise = new Promise<IpcResult<T>>((done) => {
    resolve = done
  })
  return { promise, resolve }
}
function mockBridge(invoke: unknown) {
  Object.defineProperty(window, 'ghp', {
    configurable: true,
    value: { invoke: invoke as GhpApi['invoke'], on: vi.fn(() => () => {}) },
  })
}
afterEach(() => {
  useHistoryStore.getState().reset()
  setLanguage('ko')
})

describe('history async state', () => {
  it('ignores a log response from the previous repository', async () => {
    const log = deferred<ReadonlyArray<Commit>>()
    mockBridge(
      vi.fn((channel: string) =>
        channel === 'git:log' ? log.promise : Promise.resolve({ ok: true, value: [] })
      )
    )
    useHistoryStore.getState().reset('old')
    const loading = useHistoryStore.getState().load()
    useHistoryStore.getState().reset('new')
    log.resolve({ ok: true, value: [{ sha: 'stale' } as Commit] })
    await loading
    expect(useHistoryStore.getState().repoId).toBe('new')
    expect(useHistoryStore.getState().commits).toEqual([])
    expect(useHistoryStore.getState().loading).toBe(false)
  })
  it('ignores a slow file list after selecting another commit', async () => {
    const first = deferred<ReadonlyArray<CommittedFile>>()
    mockBridge(
      vi.fn((_channel: string, _repo: string, sha: string) =>
        sha === 'first' ? first.promise : Promise.resolve({ ok: true, value: [] })
      )
    )
    useHistoryStore.getState().reset('repo')
    const pending = useHistoryStore.getState().select('first')
    await useHistoryStore.getState().select('second')
    first.resolve({ ok: true, value: [{ path: 'stale', status: { kind: AppFileStatusKind.New } }] })
    await pending
    expect(useHistoryStore.getState().selectedSha).toBe('second')
    expect(useHistoryStore.getState().files).toEqual([])
  })
  it('ignores a slow diff after selecting another file', async () => {
    const first = deferred<FileDiff>()
    mockBridge(
      vi.fn((_channel: string, _repo: string, _sha: string, path: string) =>
        path === 'first' ? first.promise : Promise.resolve({ ok: true, value: { kind: 'binary' } })
      )
    )
    useHistoryStore.getState().reset('repo')
    useHistoryStore.setState({ selectedSha: 'commit' })
    const pending = useHistoryStore.getState().selectFile('first')
    await useHistoryStore.getState().selectFile('second')
    first.resolve({ ok: true, value: { kind: 'unrenderable' } })
    await pending
    expect(useHistoryStore.getState().path).toBe('second')
    expect(useHistoryStore.getState().diff).toEqual({ kind: 'binary' })
  })
})

describe('relative time', () => {
  it('uses the app locale for past and future values', () => {
    setLanguage('en')
    expect(relativeTime(0, 60000)).toBe('1 minute ago')
    expect(relativeTime(3600000, 0)).toBe('in 1 hour')
    setLanguage('ko')
    expect(relativeTime(0, 60000)).toBe(
      new Intl.RelativeTimeFormat('ko-KR', { numeric: 'auto' }).format(-1, 'minute')
    )
  })
})
