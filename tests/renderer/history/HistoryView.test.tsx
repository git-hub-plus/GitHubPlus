// @vitest-environment jsdom
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import type { GhpApi, IpcEventMap } from '@shared/ipc'
import type { Commit } from '@shared/models/git'
import { AppFileStatusKind } from '@shared/models/status'
import { HistoryView } from '../../../src/renderer/src/components/history/HistoryView'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useHistoryStore } from '../../../src/renderer/src/state/history-store'

const commit = (sha: string, parentShas: string[] = []): Commit => ({
  sha,
  shortSha: sha,
  parentShas,
  summary: `Summary ${sha}`,
  body: `Body ${sha}`,
  tags: sha === 'a' ? ['v1'] : [],
  author: { name: 'Test Author', email: 'test@example.com', date: 1700000000000, tzOffset: 0 },
  committer: { name: 'Test Author', email: 'test@example.com', date: 1700000000000, tzOffset: 0 },
})
const files = [
  { path: 'one.ts', status: { kind: AppFileStatusKind.Modified } },
  { path: 'two.ts', status: { kind: AppFileStatusKind.New } },
]
let page: ReadonlyArray<Commit>
let changed: ((payload: IpcEventMap['git:repoChanged']) => void) | undefined
const bridge = vi.fn(async (channel: string, ...args: unknown[]): Promise<unknown> => {
  if (channel === 'git:log')
    return { ok: true, value: (args[1] as { skip: number }).skip ? [commit('older')] : page }
  if (channel === 'git:branches')
    return { ok: true, value: [{ name: 'main', type: 'local', tipSha: 'a', isCurrent: true }] }
  if (channel === 'git:commitFiles') return { ok: true, value: files }
  if (channel === 'git:commitDiff') return { ok: true, value: { kind: 'binary' } }
  throw Error(channel)
})

beforeEach(() => {
  page = [commit('a', ['b']), commit('b')]
  bridge.mockClear()
  changed = undefined
  const api: GhpApi = {
    invoke: bridge as GhpApi['invoke'],
    on: vi.fn((_event, listener) => {
      changed = listener as typeof changed
      return () => {
        changed = undefined
      }
    }),
  }
  Object.defineProperty(window, 'ghp', { value: api, configurable: true })
  useAppStore.setState({ selectedRepositoryId: 'repo' })
  useHistoryStore.getState().reset()
  localStorage.clear()
})
afterEach(cleanup)

describe('HistoryView', () => {
  it('renders graph rows, branch/tag badges and selects commit files and read-only diff', async () => {
    render(<HistoryView />)
    const list = screen.getByRole('listbox', { name: '커밋 목록' })
    const row = await within(list).findByRole('option', { name: /Summary a/ })
    expect(within(row).getByText('main').title).toBe('현재 브랜치')
    expect(within(row).getByText('v1')).toBeTruthy()
    expect(row.querySelector('svg circle')).toBeTruthy()
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:commitDiff', 'repo', 'a', 'one.ts')
    )
    fireEvent.click(within(list).getByRole('option', { name: /Summary b/ }))
    await waitFor(() => expect(bridge).toHaveBeenCalledWith('git:commitFiles', 'repo', 'b'))
    const fileList = screen.getByRole('listbox', { name: '변경 파일 목록' })
    fireEvent.click(await within(fileList).findByText('two.ts'))
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:commitDiff', 'repo', 'b', 'two.ts')
    )
    expect(screen.getByTestId('diff-view').textContent).toContain('two.ts')
  })
  it('navigates with arrows, focuses details with Enter and searches loaded commits', async () => {
    render(<HistoryView />)
    const list = screen.getByRole('listbox', { name: '커밋 목록' })
    await within(list).findByText('Summary a')
    fireEvent.keyDown(list, { key: 'ArrowDown' })
    await waitFor(() => expect(useHistoryStore.getState().selectedSha).toBe('b'))
    fireEvent.keyDown(list, { key: 'Enter' })
    expect(document.activeElement).toBe(screen.getByRole('region', { name: '커밋 상세' }))
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'Summary b' } })
    expect(within(list).queryByText('Summary a')).toBeNull()
    expect(within(list).getByText('Summary b')).toBeTruthy()
    fireEvent.change(screen.getByRole('combobox'), { target: { value: 'current' } })
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:log', 'repo', { all: false, limit: 200, skip: 0 })
    )
  })
  it('virtualizes rows and requests the next page only once at the scroll boundary', async () => {
    page = Array.from({ length: 200 }, (_, index) => commit(String(index), [String(index + 1)]))
    render(<HistoryView />)
    const list = screen.getByRole('listbox', { name: '커밋 목록' })
    await within(list).findByText('Summary 0')
    expect(within(list).getAllByRole('option').length).toBeLessThan(30)
    Object.defineProperties(list, {
      clientHeight: { value: 280 },
      scrollHeight: { value: 5600 },
      scrollTop: { value: 5320, writable: true },
    })
    fireEvent.scroll(list)
    fireEvent.scroll(list)
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:log', 'repo', { all: true, limit: 200, skip: 200 })
    )
    await waitFor(() => expect(useHistoryStore.getState().commits.length).toBe(201))
    expect(
      bridge.mock.calls.filter(
        ([channel, , query]) => channel === 'git:log' && (query as { skip: number }).skip === 200
      )
    ).toHaveLength(1)
  })
  it('refreshes the first page on repoChanged and resets on repository changes', async () => {
    render(<HistoryView />)
    await screen.findByText('Body a')
    page = [commit('new')]
    act(() => changed?.({ repoId: 'repo' }))
    await screen.findByText('Body new')
    expect(useHistoryStore.getState().commits.map((item) => item.sha)).toEqual(['new'])
    act(() => useAppStore.setState({ selectedRepositoryId: 'other' }))
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:log', 'other', { all: true, limit: 200, skip: 0 })
    )
  })
  it('shows typed errors and raw details', async () => {
    bridge.mockImplementationOnce(async () => ({
      ok: false,
      error: { kind: 'not-a-repository', message: 'Missing', detail: 'raw git stderr' },
    }))
    render(<HistoryView />)
    const alert = await screen.findByRole('alert')
    expect(alert.textContent).toContain('저장소를 찾을 수 없습니다.')
    expect(within(alert).getByText('raw git stderr')).toBeTruthy()
  })
  it('saves split width via keyboard', () => {
    render(<HistoryView />)
    fireEvent.keyDown(screen.getByRole('separator'), { key: 'ArrowRight' })
    expect(localStorage.getItem('ghp.history.splitWidth')).toBe('50')
  })
})
