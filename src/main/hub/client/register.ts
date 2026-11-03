import { createSocket } from 'node:dgram'
import { join } from 'node:path'
import { app } from 'electron'
import { handle, broadcast } from '../../ipc'
import { registerGitAuthProvider } from '../../git/core'
import { getRepository, listRepositories, registerHubUrlMatcher } from '../../store/repositories'
import { log } from '../../log'
import { HubApi } from './api'
import { HubDiscovery } from './discovery'
import { publishRepository } from './publish'
import { refreshHubGroups } from './groups'

export function register(): void {
  const api = new HubApi()
  let origins = ''
  let refresh = Promise.resolve()
  const discovery = new HubDiscovery(
    join(app.getPath('userData'), 'hub-clients.json'),
    (list) => {
      broadcast('hub:discoveredChanged', list)
      const next = list.map((hub) => hub.url).join('\n')
      if (next !== origins) {
        origins = next
        refresh = refresh
          .catch(() => undefined)
          .then(async () => {
            await refreshHubGroups((url) => discovery.matches(url))
            broadcast('repos:changed', listRepositories())
          })
        void refresh.catch((error) => log.warn('Hub repository regroup failed', error))
      }
    },
    api
  )
  registerHubUrlMatcher((url) => discovery.matches(url))
  const removeAuth = registerGitAuthProvider((args) => {
    const hubs = discovery.list()
    const direct = args.some((arg) => discovery.matches(arg))
    return {
      configArgs: [
        // URL-scoped overrides also cover named/secondary remotes, without disabling
        // credentials when the same repository fetches a non-hub remote.
        ...hubs.flatMap((hub) => ['-c', `credential.${hub.url}.helper=`]),
        ...(direct ? ['-c', 'credential.helper='] : []),
      ],
    }
  })
  const ready = discovery.load().catch((error) => log.warn('Hub discovery load failed', error))
  const socket = createSocket({ type: 'udp4', reuseAddr: true })
  socket.on('message', (message, remote) => {
    void ready.then(() => discovery.receive(message, remote.address))
  })
  socket.on('error', (error) => log.warn('Hub discovery socket failed', error))
  socket.bind(47321)
  socket.unref()
  const timer = setInterval(() => discovery.expire(), 1000)
  timer.unref()
  app.once('before-quit', () => {
    clearInterval(timer)
    try {
      socket.close()
    } catch {
      /* A failed bind may already have closed the socket. */
    }
    removeAuth()
  })
  handle('hub:discovered', async () => {
    await ready
    return discovery.list()
  })
  handle('hub:addManual', async (_, url) => {
    await ready
    return discovery.addManual(url)
  })
  handle('hub:removeManual', async (_, id) => {
    await ready
    return discovery.removeManual(id)
  })
  handle('hub:listRemoteRepositories', (_, url) => api.list(url))
  handle('hub:createRemoteRepository', (_, url, name, description) =>
    api.create(url, name, description)
  )
  handle('hub:remoteLog', (_, url, name, query) => api.log(url, name, query))
  handle('hub:remoteCommitFiles', (_, url, name, sha) => api.files(url, name, sha))
  handle('hub:remoteCommitDiff', (_, url, name, sha, path) => api.diff(url, name, sha, path))
  handle('hub:publish', async (_, id, input) => {
    await ready
    const repo = getRepository(id)
    await publishRepository(
      repo.path,
      input,
      (progress) => broadcast('git:progress', { opId: input.opId, progress }),
      api
    )
    await refresh.catch(() => undefined)
    await refreshHubGroups((url) => discovery.matches(url))
    broadcast('repos:changed', listRepositories())
    broadcast('git:repoChanged', { repoId: id })
  })
}
