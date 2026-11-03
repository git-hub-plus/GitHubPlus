// @vitest-environment jsdom
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { t } from '@shared/i18n'
import type { Branch, Commit } from '@shared/models/git'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { HistoryView } from '@renderer/components/history/HistoryView'
import { useHistoryStore } from '@renderer/state/history-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { useToastStore } from '@renderer/state/toast-store'
import { useAppStore } from '@renderer/state/app-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { setup, status } from '../app/test-utils'

const author = { name: 'Test', email: 'test@example.com', date: 1700000000000, tzOffset: 0 }
const commit = (sha: string, parentShas: string[] = []): Commit => ({
  sha,
  shortSha: sha,
  summary: `Summary ${sha}`,
  body: '',
  parentShas,
  tags: sha === 'a' ? ['v1'] : [],
  author,
  committer: author,
})
let branches: Branch[]
let page: Commit[]
let bridge: ReturnType<typeof installFakeBridge>
let outcome: OperationOutcome
let failure: { kind: string; message: string } | undefined
let pending: Promise<OperationOutcome> | undefined
beforeEach(() => {
  setup()
  useAppStore.setState({ tab: 'history' })
  useHistoryStore.getState().reset()
  useChangesStore.setState({ messageDrafts: {} })
  branches = [
    { name: 'main', type: 'local', tipSha: 'a', isCurrent: true, upstream: 'origin/main' },
    { name: 'origin/main', type: 'remote', remoteName: 'origin', tipSha: 'c', isCurrent: false },
    { name: 'topic', type: 'local', tipSha: 'x', isCurrent: false },
  ]
  page = [
    commit('a', ['b']),
    commit('b', ['c']),
    commit('x', ['y']),
    commit('y', ['c']),
    commit('c'),
  ]
  outcome = 'success'
  failure = undefined
  pending = undefined
  bridge = installFakeBridge((channel) => {
    if (channel === 'git:log') return page
    if (channel === 'git:branches') return branches
    if (channel === 'git:commitFiles') return []
    if (channel === 'git:status') return status
    if (failure) throw failure
    if (channel === 'git:undoLastCommit')
      return { summary: 'Restored summary', description: 'Restored body' }
    if (channel === 'git:rebase' && pending) return pending
    return outcome
  })
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
const list = () => screen.getByRole('listbox', { name: t('historyView.commits') })
const row = (sha: string) =>
  within(list()).getByText(`Summary ${sha}`).closest<HTMLElement>('[data-sha]')!
async function mount() {
  render(<HistoryView />)
  await within(list()).findByText('Summary a')
}
function context(sha: string) {
  fireEvent.contextMenu(row(sha), { clientX: 100, clientY: 100 })
}
function menu(
  key:
    | 'revert'
    | 'undo'
    | 'tag'
    | 'squash'
    | 'cherryPick'
    | 'deleteTag'
    | 'pushTag'
    | 'copy'
    | 'rebase'
) {
  fireEvent.click(screen.getByRole('menuitem', { name: t(`historyActions.${key}`) }))
}
function confirm() {
  fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: t('common.ok') }))
}
async function called(channel: string, ...args: unknown[]) {
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith(channel, ...args))
}

it('offers undo only at the current branch tip and cherry-pick only on other branch commits', async () => {
  await mount()
  context('a')
  expect(screen.getByRole('menuitem', { name: t('historyActions.undo') })).toBeTruthy()
  expect(screen.queryByRole('menuitem', { name: t('historyActions.cherryPick') })).toBeNull()
  fireEvent.keyDown(screen.getByRole('menu'), { key: 'Escape' })
  context('b')
  expect(screen.queryByRole('menuitem', { name: t('historyActions.undo') })).toBeNull()
  fireEvent.keyDown(screen.getByRole('menu'), { key: 'Escape' })
  context('x')
  expect(screen.getByRole('menuitem', { name: t('historyActions.cherryPick') })).toBeTruthy()
  expect(screen.queryByRole('menuitem', { name: t('historyActions.undo') })).toBeNull()
})
it('confirms revert, passes the SHA and refreshes status and first history page', async () => {
  await mount()
  context('b')
  menu('revert')
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:revert')).toBe(false)
  confirm()
  await called('git:revert', 'repo', 'b')
  await called('git:status', 'repo')
  await waitFor(() =>
    expect(bridge.invoke.mock.calls.filter(([channel]) => channel === 'git:log')).toHaveLength(2)
  )
  expect(bridge.invoke).toHaveBeenLastCalledWith('git:commitFiles', 'repo', 'b')
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.success')
})
it.each([true, false])(
  'creates annotated/lightweight tags (message present: %s)',
  async (annotated) => {
    await mount()
    context('b')
    menu('tag')
    fireEvent.change(screen.getByLabelText(t('historyActions.name')), { target: { value: 'v2' } })
    if (annotated)
      fireEvent.change(screen.getByLabelText(t('historyActions.message')), {
        target: { value: 'Release' },
      })
    confirm()
    await called('git:createTag', 'repo', {
      name: 'v2',
      sha: 'b',
      ...(annotated ? { message: 'Release' } : {}),
    })
  }
)
it('restores the undone message to the repository draft and opens Changes', async () => {
  await mount()
  context('a')
  menu('undo')
  confirm()
  await called('git:undoLastCommit', 'repo')
  await waitFor(() => expect(useAppStore.getState().tab).toBe('changes'))
  expect(useChangesStore.getState().messageDrafts.repo).toEqual({
    summary: 'Restored summary',
    description: 'Restored body',
  })
})
it('explains a rejected undo without filling a draft', async () => {
  await mount()
  failure = { kind: 'push-rejected', message: 'already pushed' }
  context('a')
  menu('undo')
  confirm()
  expect((await screen.findByRole('alert')).textContent).toContain(t('historyActions.undoRejected'))
  expect(screen.getByText('already pushed')).toBeTruthy()
  expect(useChangesStore.getState().messageDrafts.repo).toBeUndefined()
})
it('uses Ctrl selection and oldest-first squash message and arguments', async () => {
  await mount()
  fireEvent.click(row('a'))
  fireEvent.click(row('b'), { ctrlKey: true })
  expect(useHistoryStore.getState().selectedShas).toEqual(['a', 'b'])
  context('b')
  menu('squash')
  const field = screen.getByLabelText<HTMLTextAreaElement>(t('historyActions.message'))
  expect(field.value).toBe('Summary b\n\nSummary a')
  fireEvent.change(field, { target: { value: 'Combined' } })
  confirm()
  await called('git:squash', 'repo', { shas: ['b', 'a'], message: 'Combined' })
})
it('selects a visible Shift range and cherry-picks multiple other-branch commits oldest-first', async () => {
  await mount()
  fireEvent.click(row('x'))
  fireEvent.click(row('y'), { shiftKey: true })
  expect(useHistoryStore.getState().selectedShas).toEqual(['x', 'y'])
  context('x')
  menu('cherryPick')
  await called('git:cherryPick', 'repo', ['y', 'x'])
})
it('supports checkbox selection, Shift arrows and the context-menu keyboard shortcut', async () => {
  await mount()
  fireEvent.keyDown(list(), { key: 'ArrowDown', shiftKey: true })
  expect(useHistoryStore.getState().selectedShas).toEqual(['a', 'b'])
  fireEvent.keyDown(list(), { key: 'F10', shiftKey: true })
  menu('squash')
  expect(screen.getByRole('dialog')).toBeTruthy()
})
it('confirms a drag reorder with oldest-first shas and target SHA', async () => {
  await mount()
  fireEvent.click(row('b'))
  fireEvent.dragStart(row('b'))
  fireEvent.drop(row('a'))
  expect(screen.getByRole('dialog', { name: t('historyActions.reorder') })).toBeTruthy()
  confirm()
  await called('git:reorder', 'repo', { shas: ['b'], afterSha: 'a' })
})
it('warns when moving a published commit and blocks the IPC request', async () => {
  await mount()
  fireEvent.dragStart(row('c'))
  fireEvent.drop(row('a'))
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.published')
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:reorder')).toBe(false)
})
it('also blocks moving an unpushed commit across a published rewrite boundary', async () => {
  await mount()
  fireEvent.dragStart(row('a'))
  fireEvent.drop(screen.getByRole('button', { name: t('historyActions.oldest') }))
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.published')
})
it.each(['success', 'conflicts', 'nothing-to-do'] as const)(
  'handles rebase result %s and refreshes status',
  async (value) => {
    outcome = value
    await mount()
    fireEvent.click(screen.getByRole('button', { name: t('historyActions.rebase') }))
    fireEvent.change(screen.getByLabelText(t('historyActions.target')), {
      target: { value: 'topic' },
    })
    confirm()
    await called('git:rebase', 'repo', 'topic', { opId: expect.any(String) })
    await called('git:status', 'repo')
    expect(useToastStore.getState().toasts.at(-1)?.message).toBe(
      value === 'success'
        ? 'historyActions.success'
        : value === 'conflicts'
          ? 'historyActions.conflicts'
          : 'historyActions.nothing'
    )
  }
)
it('opens rebase from a branch badge and matches progress by opId', async () => {
  let resolve!: (value: OperationOutcome) => void
  pending = new Promise((done) => {
    resolve = done
  })
  await mount()
  fireEvent.contextMenu(within(list()).getByText('main'))
  menu('rebase')
  confirm()
  await waitFor(() =>
    expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:rebase')).toBe(true)
  )
  const options = bridge.invoke.mock.calls.find(([channel]) => channel === 'git:rebase')![3] as {
    opId: string
  }
  act(() =>
    bridge.emit('git:progress', {
      opId: 'other',
      progress: { kind: 'generic', title: 'Ignored', value: 0.1 },
    })
  )
  expect(screen.queryByRole('progressbar')).toBeNull()
  act(() =>
    bridge.emit('git:progress', {
      opId: options.opId,
      progress: { kind: 'generic', title: 'Applying', value: 0.5 },
    })
  )
  expect(screen.getByRole<HTMLProgressElement>('progressbar').value).toBe(0.5)
  await act(async () => resolve('success'))
})
it.each([true, false])('deletes tags with optional remote deletion (%s)', async (remote) => {
  await mount()
  fireEvent.contextMenu(within(list()).getByText('v1'))
  menu('deleteTag')
  if (remote) fireEvent.click(screen.getByLabelText(t('historyActions.deleteRemote')))
  confirm()
  await called('git:deleteTag', 'repo', 'v1', remote ? { remote: 'origin' } : undefined)
})
it('pushes a tag using an operation ID', async () => {
  await mount()
  fireEvent.contextMenu(within(list()).getByText('v1'))
  menu('pushTag')
  await called('git:pushTag', 'repo', 'v1', { opId: expect.any(String) })
})
it('copies the clicked SHA', async () => {
  const writeText = vi.fn().mockResolvedValue(undefined)
  Object.defineProperty(navigator, 'clipboard', { configurable: true, value: { writeText } })
  await mount()
  context('b')
  menu('copy')
  expect(writeText).toHaveBeenCalledWith('b')
})
it('does not refresh or switch the new repository after a delayed old operation', async () => {
  let resolve!: (value: OperationOutcome) => void
  pending = new Promise((done) => {
    resolve = done
  })
  await mount()
  fireEvent.click(screen.getByRole('button', { name: t('historyActions.rebase') }))
  confirm()
  await waitFor(() =>
    expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:rebase')).toBe(true)
  )
  act(() => useAppStore.setState({ selectedRepositoryId: 'other' }))
  await waitFor(() => expect(useHistoryStore.getState().repoId).toBe('other'))
  bridge.invoke.mockClear()
  await act(async () => resolve('success'))
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:status')).toBe(false)
})

it('allows deselecting the last selected commit', async () => {
  await mount()
  fireEvent.click(within(row('a')).getByRole('checkbox'))
  expect(useHistoryStore.getState().selectedShas).toEqual([])
})
it('opens tag actions from the badge keyboard control', async () => {
  await mount()
  fireEvent.keyDown(
    within(list()).getByRole('button', { name: t('historyActions.tagBadge', { name: 'v1' }) }),
    { key: 'Enter' }
  )
  expect(screen.getByRole('menuitem', { name: t('historyActions.pushTag') })).toBeTruthy()
})
it('blocks rewriting when the upstream boundary is not loaded', async () => {
  branches[1] = { ...branches[1], tipSha: 'unknown' }
  await mount()
  fireEvent.dragStart(row('b'))
  fireEvent.drop(row('a'))
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.unknownPush')
  expect(screen.queryByRole('dialog')).toBeNull()
})
it('does not interpret the loaded page boundary as the oldest position', async () => {
  branches = branches
    .filter((branch) => branch.type !== 'remote')
    .map((branch) => ({ ...branch, upstream: undefined }))
  page = [commit('a', ['b']), commit('b', ['missing'])]
  await mount()
  fireEvent.dragStart(row('a'))
  fireEvent.drop(screen.getByRole('button', { name: t('historyActions.oldest') }))
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.loadOlder')
})
it('suppresses duplicate submits while an operation is running', async () => {
  let resolve!: (value: OperationOutcome) => void
  pending = new Promise((done) => {
    resolve = done
  })
  await mount()
  fireEvent.click(screen.getByRole('button', { name: t('historyActions.rebase') }))
  const form = screen.getByRole('dialog').querySelector('form')!
  fireEvent.submit(form)
  fireEvent.submit(form)
  expect(bridge.invoke.mock.calls.filter(([channel]) => channel === 'git:rebase')).toHaveLength(1)
  await act(async () => resolve('success'))
})
it('sends a multi-commit reorder in oldest-first order', async () => {
  page = [commit('a', ['b']), commit('b', ['d']), commit('d', ['c']), commit('c')]
  await mount()
  fireEvent.click(row('b'))
  fireEvent.click(row('d'), { ctrlKey: true })
  fireEvent.dragStart(row('b'))
  fireEvent.drop(row('a'))
  confirm()
  await called('git:reorder', 'repo', { shas: ['d', 'b'], afterSha: 'a' })
})
it('dismisses a confirmation without invoking git', async () => {
  await mount()
  context('b')
  menu('revert')
  fireEvent.click(
    within(screen.getByRole('dialog')).getByRole('button', { name: t('common.close') })
  )
  expect(screen.queryByRole('dialog')).toBeNull()
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:revert')).toBe(false)
})
it('keeps commit message drafts isolated from selection synchronization and other repositories', () => {
  useChangesStore.getState().setMessageDraft('repo', { summary: 'Keep', description: 'Body' })
  useChangesStore.getState().sync('repo', [])
  useChangesStore.getState().sync('other', [])
  expect(useChangesStore.getState().messageDrafts.repo).toEqual({
    summary: 'Keep',
    description: 'Body',
  })
  expect(useChangesStore.getState().messageDrafts.other).toBeUndefined()
  useChangesStore.getState().clearMessageDraft('repo')
  expect(useChangesStore.getState().messageDrafts.repo).toBeUndefined()
})

it('blocks rewriting when a loaded remote tip has an unknown ancestry gap', async () => {
  branches.push({
    name: 'origin/topic',
    type: 'remote',
    remoteName: 'origin',
    tipSha: 'z',
    isCurrent: false,
  })
  page.push(commit('z', ['missing']))
  await mount()
  fireEvent.dragStart(row('b'))
  fireEvent.drop(row('a'))
  expect(useToastStore.getState().toasts.at(-1)?.message).toBe('historyActions.unknownPush')
  expect(screen.queryByRole('dialog')).toBeNull()
})
