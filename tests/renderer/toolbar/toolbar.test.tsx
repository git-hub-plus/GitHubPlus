// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { Toolbar } from '../../../src/renderer/src/components/Toolbar'
import { Toasts } from '../../../src/renderer/src/components/common/Toasts'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { useSyncStore } from '../../../src/renderer/src/state/sync-store'
import { setup, status } from '../app/test-utils'

let bridge: ReturnType<typeof setup>
beforeEach(() => {
  bridge = setup()
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
it.each([
  [undefined, 0, 0, '게시'],
  ['origin/main', 3, 2, '풀 2'],
  ['origin/main', 3, 0, '푸시 3'],
  ['origin/main', 0, 0, '가져오기'],
])(
  'selects the sync action for upstream %s ahead %s behind %s',
  (upstream, ahead, behind, label) => {
    useRepoStore.setState({ status: { ...status, upstream, ahead, behind } })
    render(<Toolbar />)
    expect(screen.getByRole('button', { name: label })).toBeTruthy()
  }
)
it('publishes with setUpstream and refreshes status', async () => {
  useRepoStore.setState({ status: { ...status, upstream: undefined } })
  render(<Toolbar />)
  fireEvent.click(screen.getByRole('button', { name: '게시' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(
      'git:push',
      'repo',
      expect.objectContaining({ setUpstream: true, branch: 'main', opId: expect.any(String) })
    )
  )
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('git:status', 'repo'))
})
it('matches progress by opId and releases the subscription after completion', async () => {
  let resolve!: (value: { ok: boolean; value: undefined }) => void
  bridge.invoke.mockImplementationOnce(
    () =>
      new Promise((done) => {
        resolve = done
      })
  )
  render(<Toolbar />)
  fireEvent.click(screen.getByRole('button', { name: '가져오기' }))
  const opId = useSyncStore.getState().active!.opId
  act(() =>
    bridge.emit('git:progress', {
      opId: 'other',
      progress: { kind: 'fetch', title: '', value: 0.9 },
    })
  )
  expect(screen.getByRole('progressbar').getAttribute('value')).toBeNull()
  act(() =>
    bridge.emit('git:progress', { opId, progress: { kind: 'fetch', title: '', value: 0.6 } })
  )
  expect(screen.getByRole('progressbar').getAttribute('value')).toBe('0.6')
  await act(async () => resolve({ ok: true, value: undefined }))
  expect(screen.queryByRole('progressbar')).toBeNull()
  expect(useSyncStore.getState().lastFetch.repo).toBeGreaterThan(0)
})
it('searches branches and checks out with a progress identifier', async () => {
  bridge.invoke.mockResolvedValueOnce({
    ok: true,
    value: [
      { name: 'main', type: 'local', tipSha: 'a', isCurrent: true },
      { name: 'feature/demo', type: 'local', tipSha: 'b', isCurrent: false },
      { name: 'origin/other', type: 'remote', tipSha: 'c', isCurrent: false },
    ],
  })
  render(<Toolbar />)
  fireEvent.click(screen.getByRole('button', { name: '브랜치 main' }))
  await screen.findByRole('button', { name: 'feature/demo' })
  fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'feature' } })
  expect(screen.queryByRole('button', { name: 'origin/other' })).toBeNull()
  fireEvent.click(screen.getByRole('button', { name: 'feature/demo' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:checkout', 'repo', 'feature/demo', {
      opId: expect.any(String),
    })
  )
})
it('shows a pull recovery action and translated error details', async () => {
  bridge.invoke.mockResolvedValueOnce({
    ok: false,
    error: { kind: 'push-needs-pull', message: 'rejected', detail: 'remote advanced' },
  } as never)
  useRepoStore.setState({ status: { ...status, ahead: 1 } })
  render(
    <>
      <Toolbar />
      <Toasts />
    </>
  )
  fireEvent.click(screen.getByRole('button', { name: '푸시 1' }))
  await screen.findByRole('button', { name: '풀' })
  expect(screen.getAllByText('먼저 풀이 필요합니다.').length).toBe(2)
  expect(screen.getByText('자세히')).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: '풀' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:pull', 'repo', { opId: expect.any(String) })
  )
})
it('shows a detached HEAD short SHA', () => {
  useRepoStore.setState({
    status: { ...status, currentBranch: undefined, headSha: '0123456789abcdef' },
  })
  render(<Toolbar />)
  expect(screen.getByRole('button', { name: '브랜치 0123456' })).toBeTruthy()
})

it.each(['rename', 'delete'] as const)('confirms branch %s and refreshes', async (action) => {
  bridge.invoke.mockResolvedValueOnce({
    ok: true,
    value: [{ name: 'topic', type: 'local', tipSha: 'a', isCurrent: false }],
  })
  render(<Toolbar />)
  fireEvent.click(screen.getByRole('button', { name: '브랜치 main' }))
  fireEvent.click(
    await screen.findByRole('button', {
      name: action === 'rename' ? 'topic 이름 변경' : 'topic 삭제',
    })
  )
  if (action === 'rename')
    fireEvent.change(screen.getByLabelText('이름'), { target: { value: 'renamed' } })
  fireEvent.click(screen.getByRole('button', { name: '확인' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(
      ...(action === 'rename'
        ? ['git:renameBranch', 'repo', 'topic', 'renamed']
        : ['git:deleteBranch', 'repo', 'topic', { deleteRemote: false }])
    )
  )
})
