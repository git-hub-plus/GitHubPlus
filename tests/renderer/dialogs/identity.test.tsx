// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { t, setLanguage } from '@shared/i18n'
import type { GitIdentity } from '@shared/ipc/git-advanced'
import { ChangesView } from '@renderer/components/changes/ChangesView'
import { PreferencesDialog } from '@renderer/components/PreferencesDialog'
import { useAppStore } from '@renderer/state/app-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { diff, status } from '../changes/fixtures'

let identity: GitIdentity
let failCommit: boolean
let failSave: boolean
let bridge: ReturnType<typeof installFakeBridge>
beforeEach(() => {
  setLanguage('ko')
  identity = { source: 'none' }
  failCommit = false
  failSave = false
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
  useAppStore.setState({ selectedRepositoryId: 'repo', preferencesOpen: false })
  useRepoStore.setState({ repoId: 'repo', status, loading: false, error: undefined })
  useChangesStore.setState({ repositories: {} })
  bridge = installFakeBridge((channel, ...args) => {
    if (channel === 'git:getIdentity') return identity
    if (channel === 'git:setIdentity') {
      if (failSave) throw { kind: 'invalid-argument', message: 'invalid email' }
      const input = args[1] as { name: string; email: string; scope: 'repository' | 'global' }
      identity = { name: input.name, email: input.email, source: input.scope }
      return identity
    }
    if (channel === 'git:workingDiff') return diff
    if (channel === 'git:status') return status
    if (channel === 'git:commit') {
      if (failCommit) {
        failCommit = false
        throw { kind: 'unknown', message: 'Please tell me who you are' }
      }
      return 'sha'
    }
  })
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
async function startCommit() {
  render(<ChangesView />)
  await screen.findByText('+new')
  fireEvent.change(screen.getByLabelText(t('changesView.summary')), {
    target: { value: 'Keep this draft' },
  })
  fireEvent.change(screen.getByLabelText(t('changesView.description')), {
    target: { value: 'Full description' },
  })
  fireEvent.click(screen.getByRole('button', { name: t('changesView.commit', { branch: 'main' }) }))
  return screen.findByRole('dialog', { name: t('identity.title') })
}
function fillIdentity(dialog: HTMLElement) {
  fireEvent.change(within(dialog).getByLabelText(t('identity.name')), {
    target: { value: 'User Name' },
  })
  fireEvent.change(within(dialog).getByLabelText(t('identity.email')), {
    target: { value: 'user@example.com' },
  })
}
it('asks for missing identity and resumes the original commit after saving', async () => {
  const dialog = await startCommit()
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:commit')).toBe(false)
  expect(within(dialog).getByText(t('identity.disclosure'))).toBeTruthy()
  expect(
    (within(dialog).getByRole('button', { name: t('common.save') }) as HTMLButtonElement).disabled
  ).toBe(true)
  fillIdentity(dialog)
  fireEvent.click(within(dialog).getByLabelText(t('identity.global')))
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.save') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:setIdentity', 'repo', {
      name: 'User Name',
      email: 'user@example.com',
      scope: 'global',
    })
  )
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(
      'git:commit',
      'repo',
      expect.objectContaining({ summary: 'Keep this draft', description: 'Full description' })
    )
  )
  await waitFor(() =>
    expect((screen.getByLabelText(t('changesView.summary')) as HTMLInputElement).value).toBe('')
  )
  expect(screen.queryByRole('dialog')).toBeNull()
})
it('preserves the draft and does not commit when identity setup is cancelled', async () => {
  const dialog = await startCommit()
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.close') }))
  expect(screen.queryByRole('dialog')).toBeNull()
  expect((screen.getByLabelText(t('changesView.summary')) as HTMLInputElement).value).toBe(
    'Keep this draft'
  )
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:commit')).toBe(false)
})
it('recovers from identity errors returned by commit, then retries once', async () => {
  identity = { name: 'Old', email: 'old@example.com', source: 'global' }
  failCommit = true
  const dialog = await startCommit()
  fillIdentity(dialog)
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.save') }))
  await waitFor(() =>
    expect(bridge.invoke.mock.calls.filter(([channel]) => channel === 'git:commit')).toHaveLength(2)
  )
})
it('detects identity errors in detail even when the main error message is generic', async () => {
  identity = { name: 'Old', email: 'old@example.com', source: 'global' }
  const original = bridge.invoke.getMockImplementation()!
  bridge.invoke.mockImplementation(async (channel, ...args) =>
    channel === 'git:commit'
      ? ({
          ok: false,
          error: { kind: 'unknown', message: 'commit failed', detail: 'Author identity unknown' },
        } as never)
      : original(channel, ...args)
  )
  await startCommit()
  expect(screen.getByRole('dialog', { name: t('identity.title') })).toBeTruthy()
})
it('keeps the dialog and draft on save failure and offers retry', async () => {
  failSave = true
  const dialog = await startCommit()
  fillIdentity(dialog)
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.save') }))
  expect(await within(dialog).findByRole('alert')).toBeTruthy()
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:commit')).toBe(false)
  failSave = false
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.save') }))
  await waitFor(() => expect(screen.queryByRole('dialog')).toBeNull())
})
it('closes pending setup on repository switch without committing to the next repository', async () => {
  await startCommit()
  act(() => {
    useAppStore.setState({ selectedRepositoryId: 'other' })
    useRepoStore.setState({ repoId: 'other', status })
  })
  expect(screen.queryByRole('dialog')).toBeNull()
  expect(bridge.invoke.mock.calls.some(([channel]) => channel === 'git:commit')).toBe(false)
})
it('shows effective identity and source in preferences and edits it', async () => {
  identity = { name: 'Current User', email: 'current@example.com', source: 'repository' }
  useAppStore.setState({ preferencesOpen: true })
  render(<PreferencesDialog />)
  await screen.findByText(/Current User/)
  expect(screen.getByText(t('identity.source', { source: t('identity.repository') }))).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: t('identity.edit') }))
  const dialog = screen.getByRole('dialog', { name: t('identity.title') })
  fireEvent.change(within(dialog).getByLabelText(t('identity.name')), {
    target: { value: 'Updated User' },
  })
  fireEvent.click(within(dialog).getByRole('button', { name: t('common.save') }))
  await screen.findByText(/Updated User/)
  expect(screen.queryByRole('dialog', { name: t('identity.title') })).toBeNull()
})
