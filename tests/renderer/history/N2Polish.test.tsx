// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { t, setLanguage } from '@shared/i18n'
import type { Branch, Commit } from '@shared/models/git'
import { HistoryView } from '@renderer/components/history/HistoryView'
import { relativeTime } from '@renderer/lib/relative-time'
import { Toolbar } from '@renderer/components/Toolbar'
import { RepositoryDialogs } from '@renderer/components/dialogs/RepositoryDialogs'
import { useAppStore } from '@renderer/state/app-store'
import { useHistoryStore } from '@renderer/state/history-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { synchronize, useSyncStore } from '@renderer/state/sync-store'
import { useDialogStore } from '@renderer/state/dialog-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { repository, status } from '../app/test-utils'

const author = { name: 'Test', email: 'test@example.com', date: 1700000000000, tzOffset: 0 }
const commit: Commit = {
  sha: 'a',
  shortSha: 'a',
  summary: 'A commit',
  body: '',
  parentShas: [],
  tags: [],
  author,
  committer: author,
}
let branches: Branch[]
let bridge: ReturnType<typeof installFakeBridge>
beforeEach(() => {
  setLanguage('ko')
  branches = [
    { name: 'main', type: 'local', tipSha: 'a', isCurrent: true },
    { name: 'origin/main', type: 'remote', remoteName: 'origin', tipSha: 'a', isCurrent: false },
  ]
  useAppStore.setState({ selectedRepositoryId: 'repo', repositories: [repository] })
  useRepoStore.setState({ repoId: 'repo', status, loading: false, error: undefined })
  useSyncStore.setState({ active: undefined, lastFetch: {}, notices: [] })
  useHistoryStore.getState().reset()
  useDialogStore.getState().close()
  Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
    configurable: true,
    value() {
      this.setAttribute('open', '')
    },
  })
  Object.defineProperty(HTMLDialogElement.prototype, 'close', {
    configurable: true,
    value() {
      this.removeAttribute('open')
    },
  })
  bridge = installFakeBridge((channel, ...args) => {
    if (channel === 'git:log') return [commit]
    if (channel === 'git:branches') return branches
    if (channel === 'git:commitFiles') return []
    if (channel === 'git:status') return status
    if (channel === 'git:createBranch') {
      const input = args[1] as { name: string }
      branches = [
        ...branches.map((branch) => ({ ...branch, isCurrent: false })),
        { name: input.name, type: 'local', tipSha: 'a', isCurrent: true },
      ]
    }
    if (channel === 'git:checkout')
      branches = branches.map((branch) => ({ ...branch, isCurrent: branch.name === args[1] }))
    if (channel === 'git:deleteBranch')
      branches = branches.filter((branch) => branch.name !== args[1])
  })
})
afterEach(() => {
  cleanup()
  vi.useRealTimers()
})
it('shows both local and remote badges on the same commit and refreshes refs on repoChanged', async () => {
  render(<HistoryView />)
  const list = screen.getByRole('listbox', { name: t('historyView.commits') })
  expect(await within(list).findByText('origin/main')).toBeTruthy()
  expect(within(list).getByText('main')).toBeTruthy()
  branches = [{ name: 'origin/new', type: 'remote', tipSha: 'a', isCurrent: false }]
  act(() => bridge.emit('git:repoChanged', { repoId: 'other' }))
  expect(within(list).queryByText('origin/new')).toBeNull()
  act(() => bridge.emit('git:repoChanged', { repoId: 'repo' }))
  await within(list).findByText('origin/new')
  expect(within(list).queryByText('origin/main')).toBeNull()
})
it.each(['fetch', 'pull', 'push', 'publish'] as const)(
  'refreshes refs, last-fetch time, and the %s completion message',
  async (command) => {
    render(
      <>
        <Toolbar />
        <HistoryView />
      </>
    )
    await screen.findByText('origin/main')
    const before = bridge.invoke.mock.calls.filter(([channel]) => channel === 'git:branches').length
    branches = [...branches, { name: 'origin/new', type: 'remote', tipSha: 'a', isCurrent: false }]
    await act(async () => {
      await synchronize(command)
    })
    expect(
      bridge.invoke.mock.calls.filter(([channel]) => channel === 'git:branches').length
    ).toBeGreaterThan(before)
    expect(screen.getByText('origin/new')).toBeTruthy()
    expect(useSyncStore.getState().lastFetch.repo).toBeGreaterThan(0)
    expect(screen.getByText(t('repoActions.fetchedNow'))).toBeTruthy()
    expect(
      screen.getByText(t(`repoActions.completed.${command}`, { branch: 'main', remote: 'origin' }))
    ).toBeTruthy()
  }
)
it('uses relative time and updates the displayed age while the toolbar stays open', () => {
  vi.useFakeTimers()
  vi.setSystemTime(new Date('2026-11-03T12:00:00Z'))
  useSyncStore.setState({ lastFetch: { repo: Date.now() - 120000 } })
  render(<Toolbar />)
  expect(
    screen.getByText(t('repoActions.lastFetch', { time: relativeTime(Date.now() - 120000) }))
  ).toBeTruthy()
  act(() => vi.advanceTimersByTime(60000))
  // The displayed time must advance without another git operation.
  expect(
    screen.getByText(t('repoActions.lastFetch', { time: relativeTime(Date.now() - 180000) }))
  ).toBeTruthy()
})
it('creates a branch, refreshes its badge, and announces the branch name', async () => {
  render(
    <>
      <Toolbar />
      <HistoryView />
      <RepositoryDialogs />
    </>
  )
  await screen.findByText('origin/main')
  act(() => useDialogStore.getState().open('branch'))
  const dialog = screen.getByRole('dialog', { name: t('repoActions.dialogs.branch') })
  fireEvent.change(within(dialog).getByLabelText(t('repoActions.name')), {
    target: { value: 'my-feature' },
  })
  fireEvent.click(within(dialog).getByRole('button', { name: t('repoActions.submit.branch') }))
  await screen.findByText('my-feature')
  await screen.findByText(t('repoActions.completed.branch', { branch: 'my-feature' }))
})
it('checks out and deletes branches without waiting for a filesystem event', async () => {
  branches.push({ name: 'topic', type: 'local', tipSha: 'a', isCurrent: false })
  render(
    <>
      <Toolbar />
      <HistoryView />
    </>
  )
  await screen.findByText('origin/main')
  fireEvent.click(screen.getByRole('button', { name: new RegExp(t('toolbar.branch') + ' main') }))
  fireEvent.click(await screen.findByRole('button', { name: 'topic' }))
  await screen.findByText(t('repoActions.completed.checkout', { branch: 'topic' }))
  const list = screen.getByRole('listbox', { name: t('historyView.commits') })
  await waitFor(() =>
    expect(within(list).getByText('topic').title).toBe(t('historyView.currentBranch'))
  )
  fireEvent.click(screen.getByRole('button', { name: new RegExp(t('toolbar.branch') + ' main') }))
  fireEvent.click(
    await screen.findByRole('button', { name: t('repoActions.deleteBranch', { branch: 'main' }) })
  )
  const dialog = screen.getByRole('dialog', { name: t('repoActions.delete') })
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.ok') }))
  await waitFor(() => expect(within(list).queryByText('main')).toBeNull())
})

it('moves focus across local/remote group headings using the common list', async () => {
  render(<Toolbar />)
  fireEvent.click(screen.getByRole('button', { name: new RegExp(t('toolbar.branch') + ' main') }))
  const rename = await screen.findByRole('button', {
    name: t('repoActions.renameBranch', { branch: 'main' }),
  })
  rename.focus()
  fireEvent.keyDown(rename, { key: 'ArrowDown' })
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'origin/main' }))
})
it('keeps the previous fetch timestamp when synchronization fails', async () => {
  useSyncStore.setState({ lastFetch: { repo: 123 } })
  const original = bridge.invoke.getMockImplementation()!
  bridge.invoke.mockImplementation((channel, ...args) =>
    channel === 'git:push'
      ? (Promise.resolve({ ok: false, error: { kind: 'network', message: 'offline' } }) as never)
      : original(channel, ...args)
  )
  await synchronize('push')
  expect(useSyncStore.getState().lastFetch.repo).toBe(123)
  expect(useSyncStore.getState().notices).toHaveLength(0)
})
