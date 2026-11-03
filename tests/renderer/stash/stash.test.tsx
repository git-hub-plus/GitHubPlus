// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, expect, it } from 'vitest'
import { AppFileStatusKind, UnmergedEntrySummary } from '@shared/models/status'
import { StashMenu } from '@renderer/components/stash/StashMenu'
import { InProgressBanner } from '@renderer/components/conflicts/InProgressBanner'
import { useOperationStore } from '@renderer/state/operation-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { setup, status } from '../app/test-utils'
const entries = [
  { name: 'stash@{0}', sha: 'a', message: 'First', branchName: 'topic', createdAt: 1000 },
  { name: 'stash@{1}', sha: 'b', message: 'Second', branchName: 'main', createdAt: 2000 },
]
beforeEach(() => {
  setup()
  useOperationStore.setState({ busy: {} })
})
afterEach(cleanup)
function openMenu() {
  fireEvent.click(screen.getByRole('button', { name: '임시 저장(stash)' }))
}
it('creates a stash with a message and untracked files', async () => {
  const bridge = installFakeBridge((channel) => (channel === 'git:status' ? status : undefined))
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '변경 사항 임시 저장…' }))
  fireEvent.change(screen.getByLabelText('임시 저장 메시지'), {
    target: { value: 'work in progress' },
  })
  fireEvent.click(screen.getByLabelText('추적하지 않는 파일 포함'))
  fireEvent.click(
    within(screen.getByRole('dialog')).getByRole('button', { name: '변경 사항 임시 저장…' })
  )
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:stashCreate', 'repo', {
      message: 'work in progress',
      includeUntracked: true,
    })
  )
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
  expect(bridge.invoke).toHaveBeenCalledWith('git:status', 'repo')
})
it.each([false, true])('lists metadata and readonly files, then applies pop=%s', async (pop) => {
  const bridge = installFakeBridge((channel) =>
    channel === 'git:stashList'
      ? entries
      : channel === 'git:stashFiles'
        ? [{ path: 'a.ts', status: { kind: AppFileStatusKind.Modified } }]
        : channel === 'git:stashDiff'
          ? { kind: 'binary' }
          : channel === 'git:status'
            ? status
            : 'success'
  )
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  await screen.findByRole('button', { name: 'stash@{0} — First' })
  expect(screen.getByText('topic')).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: 'stash@{1} — Second' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:stashDiff', 'repo', 'stash@{1}', 'a.ts')
  )
  expect(screen.queryByRole('checkbox')).toBeNull()
  fireEvent.click(screen.getByRole('button', { name: pop ? '꺼내기(pop)' : '적용' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:stashApply', 'repo', 'stash@{1}', { pop })
  )
  await waitFor(() =>
    expect(bridge.invoke.mock.calls.filter((c) => c[0] === 'git:stashList')).toHaveLength(2)
  )
})
it('shows conflicts from stash apply in the workspace banner without an operation', async () => {
  let applied = false
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:stashList') return entries
    if (channel === 'git:stashFiles') return []
    if (channel === 'git:stashApply') {
      applied = true
      return 'conflicts'
    }
    if (channel === 'git:status')
      return applied
        ? {
            ...status,
            files: [
              {
                path: 'a',
                status: {
                  kind: AppFileStatusKind.Conflicted,
                  action: UnmergedEntrySummary.BothModified,
                },
              },
            ],
          }
        : status
  })
  render(
    <>
      <StashMenu repoId="repo" />
      <InProgressBanner />
    </>
  )
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  fireEvent.click(await screen.findByRole('button', { name: '적용' }))
  await screen.findByText('충돌 — 충돌 파일 1개')
  expect(screen.queryByRole('button', { name: '이어서 하기' })).toBeNull()
  expect(bridge.invoke).toHaveBeenCalledWith('git:status', 'repo')
})
it('confirms drop and reloads the list', async () => {
  let dropped = false
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:stashList') return dropped ? [] : entries
    if (channel === 'git:stashFiles') return []
    if (channel === 'git:stashDrop') dropped = true
    if (channel === 'git:status') return status
  })
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  fireEvent.click(await screen.findByRole('button', { name: '버리기' }))
  expect(bridge.invoke).not.toHaveBeenCalledWith('git:stashDrop', 'repo', 'stash@{0}')
  fireEvent.click(
    within(screen.getByRole('dialog', { name: '버리기' })).getByRole('button', { name: '버리기' })
  )
  await screen.findByText('임시 저장이 없습니다')
  expect(bridge.invoke).toHaveBeenCalledWith('git:stashDrop', 'repo', 'stash@{0}')
})
it('handles an empty list', async () => {
  installFakeBridge(() => [])
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  await screen.findByText('임시 저장이 없습니다')
  expect(screen.queryByRole('button', { name: '적용' })).toBeNull()
})

it('ignores stale file and diff responses while changing stash selection with the keyboard', async () => {
  let resolveFiles!: (value: unknown) => void
  let resolveDiff!: (value: unknown) => void
  const bridge = installFakeBridge((channel, ...args) => {
    if (channel === 'git:stashList') return entries
    if (channel === 'git:stashFiles')
      return args[1] === 'stash@{0}'
        ? new Promise((resolve) => {
            resolveFiles = resolve
          })
        : [{ path: 'second.ts', status: { kind: AppFileStatusKind.Modified } }]
    if (channel === 'git:stashDiff')
      return new Promise((resolve) => {
        resolveDiff = resolve
      })
  })
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  await screen.findByRole('button', { name: 'stash@{0} — First' })
  await waitFor(() => expect(resolveFiles).toBeTypeOf('function'))
  fireEvent.keyDown(screen.getByRole('listbox', { name: '임시 저장 목록' }), { key: 'ArrowDown' })
  await screen.findByRole('button', { name: 'second.ts' })
  await act(async () =>
    resolveFiles([{ path: 'stale.ts', status: { kind: AppFileStatusKind.Modified } }])
  )
  expect(screen.queryByRole('button', { name: 'stale.ts' })).toBeNull()
  expect(bridge.invoke).toHaveBeenCalledWith('git:stashDiff', 'repo', 'stash@{1}', 'second.ts')
  fireEvent.click(screen.getByRole('button', { name: '닫기' }))
  await act(async () => resolveDiff({ kind: 'binary' }))
  expect(screen.queryByRole('dialog')).toBeNull()
})
it('keeps the selected stash identity after pop renumbers the list', async () => {
  let popped = false
  const bridge = installFakeBridge((channel) => {
    if (channel === 'git:stashList')
      return popped ? [{ ...entries[1], name: 'stash@{0}' }] : entries
    if (channel === 'git:stashFiles') return []
    if (channel === 'git:stashApply') {
      popped = true
      return 'success'
    }
    if (channel === 'git:status') return status
  })
  render(<StashMenu repoId="repo" />)
  openMenu()
  fireEvent.click(screen.getByRole('button', { name: '임시 저장 목록' }))
  fireEvent.click(await screen.findByRole('button', { name: '꺼내기(pop)' }))
  await screen.findByRole('button', { name: 'stash@{0} — Second' })
  fireEvent.click(screen.getByRole('button', { name: '적용' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:stashApply', 'repo', 'stash@{0}', {
      pop: false,
    })
  )
})
