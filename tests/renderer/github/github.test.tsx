// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { t } from '@shared/i18n'
import type { GitHubAccount } from '@shared/ipc/integrations'
import { GitHubAccountSection } from '../../../src/renderer/src/components/github/GitHubAccountSection'
import { GitHubPublishDialog } from '../../../src/renderer/src/components/github/GitHubPublishDialog'
import { githubRepositoryMenuItems } from '../../../src/renderer/src/components/github/repository-menu'
import { RepositoryDialogs } from '../../../src/renderer/src/components/dialogs/RepositoryDialogs'
import { useGitHubStore } from '../../../src/renderer/src/state/github-store'
import { useDialogStore } from '../../../src/renderer/src/state/dialog-store'
import { useToastStore } from '../../../src/renderer/src/state/toast-store'
import { useSyncStore } from '../../../src/renderer/src/state/sync-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { repository, setup } from '../app/test-utils'

const account = { login: 'octocat', avatarUrl: 'https://github.com/avatar.png' }
const flow = {
  userCode: 'ABCD-1234',
  verificationUri: 'https://github.com/login/device',
  expiresAt: Date.now() + 60000,
  intervalSeconds: 5,
}
let complete: (account: GitHubAccount) => void
let bridge: ReturnType<typeof installFakeBridge>
const clipboard = vi.fn().mockResolvedValue(undefined)
beforeEach(() => {
  setup()
  useGitHubStore.setState({ account: null, repositories: [] })
  Object.defineProperty(navigator, 'clipboard', {
    configurable: true,
    value: { writeText: clipboard },
  })
  bridge = installFakeBridge((channel) => {
    if (channel === 'github:account') return null
    if (channel === 'github:beginDeviceFlow') return flow
    if (channel === 'github:completeDeviceFlow')
      return new Promise<GitHubAccount>((resolve) => {
        complete = resolve
      })
    if (channel === 'github:repositories')
      return [
        {
          fullName: 'octocat/private',
          cloneUrl: 'https://github.com/octocat/private.git',
          private: true,
          updatedAt: 0,
        },
        {
          fullName: 'octocat/public',
          cloneUrl: 'https://github.com/octocat/public.git',
          private: false,
          updatedAt: 0,
        },
      ]
    if (channel === 'github:publish') return { ...repository, group: 'github' }
  })
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
  clipboard.mockClear()
})
it('shows the device code, copies it, exposes the external link and finishes sign-in', async () => {
  render(<GitHubAccountSection />)
  fireEvent.click(await screen.findByRole('button', { name: t('github.signIn') }))
  expect(await screen.findByLabelText(t('github.userCode'))).toHaveProperty(
    'textContent',
    flow.userCode
  )
  fireEvent.click(screen.getByRole('button', { name: t('github.copy') }))
  await waitFor(() => expect(clipboard).toHaveBeenCalledWith(flow.userCode))
  const link = screen.getByRole('link', { name: t('github.openBrowser') })
  expect(link.getAttribute('href')).toBe(flow.verificationUri)
  expect(link.getAttribute('target')).toBe('_blank')
  await act(async () => complete(account))
  expect(await screen.findByText('octocat')).toBeTruthy()
  expect(screen.queryByRole('dialog')).toBeNull()
  expect(useToastStore.getState().toasts.some((toast) => toast.message === 'github.signedIn')).toBe(
    true
  )
})
it('cancels polling and ignores a late completed account', async () => {
  render(<GitHubAccountSection />)
  fireEvent.click(await screen.findByRole('button', { name: t('github.signIn') }))
  await screen.findByLabelText(t('github.userCode'))
  fireEvent.click(screen.getByRole('button', { name: t('common.cancel') }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('github:cancelDeviceFlow'))
  await act(async () => complete(account))
  expect(useGitHubStore.getState().account).toBeNull()
  expect(screen.queryByRole('dialog')).toBeNull()
})
it('signs out and clears cached repositories', async () => {
  bridge.invoke.mockImplementation(
    async (channel) =>
      ({ ok: true, value: channel === 'github:account' ? account : undefined }) as never
  )
  render(<GitHubAccountSection />)
  fireEvent.click(await screen.findByRole('button', { name: t('github.signOut') }))
  await waitFor(() => expect(useGitHubStore.getState().account).toBeNull())
  expect(bridge.invoke).toHaveBeenCalledWith('github:signOut')
  expect(useGitHubStore.getState().repositories).toEqual([])
})
it('filters GitHub repositories and fills the clone URL after keyboard selection', async () => {
  bridge.invoke.mockImplementationOnce(async () => ({ ok: true, value: account }) as never)
  useDialogStore.getState().open('clone')
  render(<RepositoryDialogs />)
  fireEvent.click(screen.getByRole('tab', { name: 'GitHub' }))
  await screen.findByRole('option', { name: /octocat\/private/ })
  fireEvent.change(screen.getByLabelText(t('github.search')), { target: { value: 'private' } })
  expect(screen.queryByRole('option', { name: 'octocat/public' })).toBeNull()
  const item = screen.getByRole('option', { name: /octocat\/private/ })
  item.focus()
  fireEvent.keyDown(item, { key: 'ArrowDown' })
  expect(document.activeElement).toBe(item)
  fireEvent.click(item)
  expect((screen.getByLabelText(t('repoActions.url')) as HTMLInputElement).value).toBe(
    'https://github.com/octocat/private.git'
  )
  fireEvent.click(screen.getByRole('tab', { name: 'URL' }))
  expect((screen.getByLabelText(t('repoActions.url')) as HTMLInputElement).value).toBe(
    'https://github.com/octocat/private.git'
  )
})
it('publishes the folder name, description, privacy and operation id', async () => {
  bridge.invoke.mockImplementationOnce(async () => ({ ok: true, value: account }) as never)
  const close = vi.fn()
  render(<GitHubPublishDialog repository={repository} onClose={close} />)
  expect((screen.getByLabelText(t('github.name')) as HTMLInputElement).value).toBe('example')
  await screen.findByRole('button', { name: t('github.publish') })
  await waitFor(() => expect(useGitHubStore.getState().account).toEqual(account))
  fireEvent.change(screen.getByLabelText(t('github.name')), { target: { value: 'new-repo' } })
  fireEvent.change(screen.getByLabelText(t('github.description')), {
    target: { value: ' Description ' },
  })
  fireEvent.click(screen.getByRole('checkbox'))
  fireEvent.click(screen.getByRole('button', { name: t('github.publish') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('github:publish', repository.id, {
      name: 'new-repo',
      description: 'Description',
      private: false,
      opId: expect.any(String),
    })
  )
  await waitFor(() => expect(close).toHaveBeenCalled())
  expect(
    useToastStore.getState().toasts.some((toast) => toast.message === 'github.published')
  ).toBe(true)
  expect(useSyncStore.getState().active).toBeUndefined()
})
it('offers publishing only for local repositories and mounts its sidebar dialog', async () => {
  expect(githubRepositoryMenuItems({ ...repository, group: 'github' })).toEqual([])
  expect(githubRepositoryMenuItems({ ...repository, group: 'hub' })).toEqual([])
  const item = githubRepositoryMenuItems(repository)[0]
  expect(item.label).toBe(t('github.publishMenu'))
  await act(async () => item.onSelect(repository))
  expect(screen.getByRole('dialog', { name: t('github.publishTitle') })).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: t('common.close') }))
  expect(screen.queryByRole('dialog')).toBeNull()
})
