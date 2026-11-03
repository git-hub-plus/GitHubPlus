// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { AppFileStatusKind, UnmergedEntrySummary } from '@shared/models/status'
import { InProgressBanner } from '@renderer/components/conflicts/InProgressBanner'
import { ConflictFileActions } from '@renderer/components/conflicts/ConflictFileActions'
import { BranchPopover } from '@renderer/components/toolbar/BranchPopover'
import { ChangesView } from '@renderer/components/changes/ChangesView'
import { Toasts } from '@renderer/components/common/Toasts'
import { useOperationStore } from '@renderer/state/operation-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { setup, status } from '../app/test-utils'

const conflict = {
  kind: AppFileStatusKind.Conflicted,
  action: UnmergedEntrySummary.BothModified,
  conflictMarkerCount: 2,
} as const
const branches = [
  { name: 'main', type: 'local', isCurrent: true, tipSha: 'a' },
  { name: 'topic', type: 'local', isCurrent: false, tipSha: 'b' },
]
beforeEach(() => {
  setup()
  useOperationStore.setState({ busy: {} })
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
it.each(['success', 'conflicts', 'nothing-to-do'])(
  'merges with squash and notifies %s',
  async (outcome) => {
    const bridge = installFakeBridge((channel) =>
      channel === 'git:branches' ? branches : channel === 'git:status' ? status : outcome
    )
    render(
      <>
        <BranchPopover repoId="repo" onClose={() => {}} />
        <Toasts />
      </>
    )
    fireEvent.click(await screen.findByRole('button', { name: 'topic 병합' }))
    expect(screen.getByText('topic → main')).toBeTruthy()
    fireEvent.click(screen.getByLabelText('합치기(squash)로 병합'))
    const dialog = screen.getByRole('dialog', { name: '현재 브랜치로 병합' })
    fireEvent.click(within(dialog).getByRole('button', { name: '병합' }))
    await waitFor(() =>
      expect(bridge.invoke).toHaveBeenCalledWith('git:merge', 'repo', 'topic', { squash: true })
    )
    await screen.findByText(
      outcome === 'success'
        ? '작업을 완료했습니다'
        : outcome === 'conflicts'
          ? '충돌이 있습니다. 파일을 해결한 뒤 이어서 진행하세요.'
          : '이미 최신입니다'
    )
    expect(bridge.invoke).toHaveBeenCalledWith('git:status', 'repo')
  }
)
it('disables continue until conflicts clear and confirms the merge message', async () => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : 'success'))
  useRepoStore.setState({
    status: {
      ...status,
      inProgress: { kind: 'merge', theirBranch: 'topic' },
      files: [{ path: 'a', status: conflict }],
    },
  })
  render(<InProgressBanner />)
  expect(screen.getByText('topic을 병합하는 중 — 충돌 파일 1개')).toBeTruthy()
  expect((screen.getByRole('button', { name: '이어서 하기' }) as HTMLButtonElement).disabled).toBe(
    true
  )
  act(() =>
    useRepoStore.setState({
      status: { ...status, inProgress: { kind: 'merge', theirBranch: 'topic' } },
    })
  )
  fireEvent.click(screen.getByRole('button', { name: '이어서 하기' }))
  fireEvent.change(screen.getByLabelText('커밋 메시지'), { target: { value: 'Merge topic' } })
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: '이어서 하기' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:continueOperation', 'repo', {
      message: 'Merge topic',
    })
  )
})
it.each(['rebase', 'cherry-pick', 'revert'] as const)('continues %s directly', async (kind) => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : 'success'))
  const op =
    kind === 'rebase'
      ? { kind, targetBranch: 'main', step: 1, totalSteps: 2 }
      : kind === 'cherry-pick'
        ? { kind, step: 1, totalSteps: 2 }
        : { kind }
  useRepoStore.setState({ status: { ...status, inProgress: op } })
  render(<InProgressBanner />)
  fireEvent.click(screen.getByRole('button', { name: '이어서 하기' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:continueOperation', 'repo', undefined)
  )
})
it('aborts only after confirmation and permits cancellation', async () => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : undefined))
  useRepoStore.setState({ status: { ...status, inProgress: { kind: 'revert' } } })
  render(<InProgressBanner />)
  fireEvent.click(screen.getByRole('button', { name: '중단' }))
  expect(bridge.invoke).not.toHaveBeenCalledWith('git:abortOperation', 'repo')
  fireEvent.click(screen.getByRole('button', { name: '닫기' }))
  expect(screen.queryByRole('dialog')).toBeNull()
  fireEvent.click(screen.getByRole('button', { name: '중단' }))
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: '중단' }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('git:abortOperation', 'repo'))
})
it.each([
  ['내 것 사용', 'ours'],
  ['상대 것 사용', 'theirs'],
])('resolves using %s', async (label, choice) => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : undefined))
  render(<ConflictFileActions repoId="repo" path="a" status={conflict} />)
  fireEvent.click(screen.getByRole('button', { name: label }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:resolveConflict', 'repo', 'a', choice)
  )
})
it('warns before marking files with markers resolved', async () => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : undefined))
  render(<ConflictFileActions repoId="repo" path="a" status={conflict} />)
  expect(screen.getByText('남은 충돌 표시 2개')).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: '해결됨으로 표시' }))
  expect(bridge.invoke).not.toHaveBeenCalledWith('git:markResolved', 'repo', ['a'])
  fireEvent.click(screen.getByRole('button', { name: '확인' }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('git:markResolved', 'repo', ['a']))
})
it('marks clean text conflicts directly and hides mark for binary conflicts', async () => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : undefined))
  const view = render(
    <ConflictFileActions repoId="repo" path="a" status={{ ...conflict, conflictMarkerCount: 0 }} />
  )
  fireEvent.click(screen.getByRole('button', { name: '해결됨으로 표시' }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('git:markResolved', 'repo', ['a']))
  view.rerender(
    <ConflictFileActions
      repoId="repo"
      path="a"
      status={{ ...conflict, conflictMarkerCount: undefined }}
    />
  )
  expect(screen.queryByRole('button', { name: '해결됨으로 표시' })).toBeNull()
})
it('stashes untracked changes before retrying failed checkout', async () => {
  let attempts = 0
  const close = vi.fn()
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:branches') return branches
    if (channel === 'git:status') return status
    if (channel === 'git:checkout' && ++attempts === 1)
      throw { kind: 'local-changes-overwritten', message: 'blocked' }
  })
  render(<BranchPopover repoId="repo" onClose={close} />)
  fireEvent.click(await screen.findByRole('button', { name: 'topic' }))
  await screen.findByText('변경 사항을 임시 저장하고 전환할까요?')
  expect(bridge.invoke).not.toHaveBeenCalledWith('git:stashCreate', 'repo', expect.anything())
  fireEvent.click(screen.getByRole('button', { name: '확인' }))
  await waitFor(() => expect(close).toHaveBeenCalled())
  const channels = bridge.invoke.mock.calls.map((c) => c[0])
  expect(channels.filter((c) => c === 'git:checkout')).toHaveLength(2)
  expect(channels.indexOf('git:stashCreate')).toBeLessThan(channels.lastIndexOf('git:checkout'))
  expect(bridge.invoke).toHaveBeenCalledWith('git:stashCreate', 'repo', { includeUntracked: true })
})
it('keeps the branch in place if stash fails and exposes error details', async () => {
  let attempts = 0
  installFakeBridge((channel) => {
    if (channel === 'git:branches') return branches
    if (channel === 'git:status') return status
    if (channel === 'git:checkout') {
      attempts++
      throw { kind: 'local-changes-overwritten', message: 'blocked' }
    }
    if (channel === 'git:stashCreate') throw { kind: 'not-found', message: 'missing stash' }
  })
  render(
    <>
      <BranchPopover repoId="repo" onClose={() => {}} />
      <Toasts />
    </>
  )
  fireEvent.click(await screen.findByRole('button', { name: 'topic' }))
  fireEvent.click(await screen.findByRole('button', { name: '확인' }))
  await screen.findByText('missing stash')
  expect(attempts).toBe(1)
  expect(screen.getByText('자세히')).toBeTruthy()
})
it('connects compact conflict controls to change rows and disables ordinary commits', async () => {
  const conflicted = { ...status, files: [{ path: 'a', status: conflict }] }
  useRepoStore.setState({ status: conflicted })
  installFakeBridge((channel) => (channel === 'git:workingDiff' ? { kind: 'binary' } : conflicted))
  render(<ChangesView />)
  fireEvent.click(screen.getByRole('button', { name: '충돌' }))
  expect(screen.getByRole('button', { name: '내 것 사용' })).toBeTruthy()
  expect((screen.getByLabelText('a 커밋에 포함') as HTMLInputElement).disabled).toBe(true)
  expect((screen.getByRole('button', { name: 'main에 커밋' }) as HTMLButtonElement).disabled).toBe(
    true
  )
  await screen.findByText('남은 충돌 표시 2개')
})

it('keeps a failed merge open with squash off and allows retry', async () => {
  let failed = true
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:branches') return branches
    if (channel === 'git:status') return status
    if (channel === 'git:merge' && failed)
      throw { kind: 'merge-conflicts', message: 'resolve first' }
    return 'success'
  })
  render(
    <>
      <BranchPopover repoId="repo" onClose={() => {}} />
      <Toasts />
    </>
  )
  fireEvent.click(await screen.findByRole('button', { name: 'topic 병합' }))
  const dialog = screen.getByRole('dialog', { name: '현재 브랜치로 병합' })
  fireEvent.click(within(dialog).getByRole('button', { name: '병합' }))
  await screen.findByText('resolve first')
  expect(bridge.invoke).toHaveBeenCalledWith('git:merge', 'repo', 'topic', { squash: false })
  await waitFor(() => expect(useOperationStore.getState().busy.repo).toBe(false))
  failed = false
  fireEvent.click(within(dialog).getByRole('button', { name: '병합' }))
  await waitFor(() =>
    expect(screen.queryByRole('dialog', { name: '현재 브랜치로 병합' })).toBeNull()
  )
})
it('does not repeat checkout when the stash confirmation is cancelled', async () => {
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:branches') return branches
    if (channel === 'git:checkout') throw { kind: 'local-changes-overwritten', message: 'blocked' }
  })
  render(<BranchPopover repoId="repo" onClose={() => {}} />)
  fireEvent.click(await screen.findByRole('button', { name: 'topic' }))
  fireEvent.click(await screen.findByRole('button', { name: '닫기' }))
  expect(bridge.invoke.mock.calls.filter((c) => c[0] === 'git:checkout')).toHaveLength(1)
  expect(bridge.invoke.mock.calls.some((c) => c[0] === 'git:stashCreate')).toBe(false)
})
