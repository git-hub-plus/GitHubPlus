import { join } from 'node:path'
import { app, safeStorage } from 'electron'
import { handle, broadcast } from '../ipc'
import { log } from '../log'
import { git, registerGitAuthProvider } from '../git/core'
import {
  getRepository,
  listRepositories,
  onRepositoriesChanged,
  updateRepository,
} from '../store/repositories'
import { GITHUB_OAUTH_CLIENT_ID } from './config'
import { TokenStore } from './token-store'
import { GitHubService } from './service'
import { createGitHubAuthProvider } from './auth'
import { createPublisher } from './publish'

/** Registers the fixed GitHub IPC contract without exposing token data. */
export function register(): void {
  const tokens = new TokenStore(
    join(app.getPath('userData'), 'github-token.bin'),
    safeStorage,
    log.warn
  )
  const ready = tokens.load().catch(() => log.warn('GitHub 토큰 저장소를 읽지 못했습니다'))
  const service = new GitHubService({ clientId: GITHUB_OAUTH_CLIENT_ID, tokens })
  const origins = new Map<string, string>()
  let revision = 0
  const refresh = (repos: ReturnType<typeof listRepositories>): void => {
    const current = ++revision
    origins.clear()
    for (const repo of repos) if (repo.remoteUrl) origins.set(repo.path, repo.remoteUrl)
    // Repository opens update lastOpenedAt and trigger this listener. Refresh the
    // synchronous auth cache from git without ever running git inside a provider.
    for (const repo of repos) {
      if (!repo.available) continue
      void git(['config', '--get', 'remote.origin.url'], repo.path, 'githubOrigin', {
        successExitCodes: new Set([0, 1]),
      })
        .then((result) => {
          if (revision !== current) return
          const url = result.stdout.trim()
          if (url) origins.set(repo.path, url)
          else origins.delete(repo.path)
        })
        .catch(() => undefined)
    }
  }
  refresh(listRepositories())
  onRepositoriesChanged(refresh)
  registerGitAuthProvider(
    createGitHubAuthProvider(
      () => tokens.get(),
      (path) => origins.get(path)
    )
  )
  const publish = createPublisher(service, {
    getRepository,
    updateRepository,
    cacheOrigin: (path, url) => {
      revision++
      origins.set(path, url)
    },
  })
  handle('github:account', async () => {
    await ready
    return service.account()
  })
  handle('github:beginDeviceFlow', async () => {
    await ready
    return service.beginDeviceFlow()
  })
  handle('github:completeDeviceFlow', () => service.completeDeviceFlow())
  handle('github:cancelDeviceFlow', () => service.cancelDeviceFlow())
  handle('github:signOut', async () => {
    await ready
    await service.signOut()
  })
  handle('github:repositories', async () => {
    await ready
    return service.repositories()
  })
  handle('github:publish', async (_event, id, input) => {
    await ready
    return publish(id, input, (progress) =>
      broadcast('git:progress', { opId: input.opId, progress })
    )
  })
}
