// @vitest-environment jsdom
import { beforeEach, expect, it } from 'vitest'
import { useGitHubStore } from '../../../src/renderer/src/state/github-store'
import { installFakeBridge } from '../helpers/fake-bridge'

const account = { login: 'octocat' }
const repositories = [
  {
    fullName: 'octocat/private',
    cloneUrl: 'https://github.com/octocat/private.git',
    private: true,
    updatedAt: 0,
  },
]
beforeEach(() => {
  useGitHubStore.getState().setAccount(account)
  useGitHubStore.setState({ repositories })
})
it.each(['refreshAccount', 'loadRepositories'] as const)(
  'clears cached account and repositories on %s authentication failure',
  async (method) => {
    installFakeBridge(() => {
      throw { kind: 'authentication-failed', message: 'Expired' }
    })
    await expect(useGitHubStore.getState()[method]()).rejects.toMatchObject({
      kind: 'authentication-failed',
    })
    expect(useGitHubStore.getState().account).toBeNull()
    expect(useGitHubStore.getState().repositories).toEqual([])
  }
)
it('does not overwrite a newly signed-in account with a stale account refresh', async () => {
  let resolve!: (value: null) => void
  installFakeBridge(
    () =>
      new Promise<null>((done) => {
        resolve = done
      })
  )
  const refreshing = useGitHubStore.getState().refreshAccount()
  useGitHubStore.getState().setAccount({ login: 'new-user' })
  resolve(null)
  await refreshing
  expect(useGitHubStore.getState().account?.login).toBe('new-user')
})
it('ignores account and private repository responses arriving after sign-out', async () => {
  let resolveAccount!: (value: typeof account) => void
  let resolveRepositories!: (value: typeof repositories) => void
  installFakeBridge((channel) => {
    if (channel === 'github:account')
      return new Promise<typeof account>((resolve) => {
        resolveAccount = resolve
      })
    if (channel === 'github:repositories')
      return new Promise<typeof repositories>((resolve) => {
        resolveRepositories = resolve
      })
  })
  const refreshing = useGitHubStore.getState().refreshAccount()
  const listing = useGitHubStore.getState().loadRepositories()
  await useGitHubStore.getState().signOut()
  resolveAccount(account)
  resolveRepositories(repositories)
  await Promise.all([refreshing, listing])
  expect(useGitHubStore.getState().account).toBeNull()
  expect(useGitHubStore.getState().repositories).toEqual([])
})
it('does not let an expired old session clear a newer signed-in account', async () => {
  let reject!: (reason: unknown) => void
  installFakeBridge(
    () =>
      new Promise((_, fail) => {
        reject = fail
      })
  )
  const refreshing = useGitHubStore.getState().refreshAccount()
  useGitHubStore.getState().setAccount({ login: 'new-user' })
  reject({ kind: 'authentication-failed', message: 'Old session expired' })
  await expect(refreshing).rejects.toMatchObject({ kind: 'authentication-failed' })
  expect(useGitHubStore.getState().account?.login).toBe('new-user')
})
