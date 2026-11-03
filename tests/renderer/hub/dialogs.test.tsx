// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { setLanguage, t } from '@shared/i18n'
import type { HubSettings } from '@shared/ipc/hub'
import type { Commit } from '@shared/models/git'
import { HubDialogs, RemoteHistory } from '../../../src/renderer/src/components/hub/HubDialogs'
import { HubGroupMenu } from '../../../src/renderer/src/components/hub/HubGroupMenu'
import { useHubStore } from '../../../src/renderer/src/state/hub-store'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { installFakeBridge } from '../helpers/fake-bridge'

const hubs = [
  {
    id: 'http://192.168.0.1:8765',
    url: 'http://192.168.0.1:8765',
    name: 'Office',
    online: true,
    manual: false,
    lastSeen: 1,
  },
  {
    id: 'http://192.168.0.2:8765',
    url: 'http://192.168.0.2:8765',
    name: 'Lab',
    online: true,
    manual: true,
    lastSeen: 1,
  },
]
const repo = {
  id: 'cloned',
  name: 'team',
  path: 'C:/repos/team',
  group: 'hub' as const,
  pinned: false,
  available: true,
  addedAt: 1,
}
const remote = { name: 'team', description: 'Shared project', url: `${hubs[1].url}/team.git` }
const settings: HubSettings = {
  enabled: false,
  port: 8765,
  name: 'My hub',
  rootDirectory: 'C:/hub',
  keepRunningInTray: true,
  startWithWindows: false,
}
const commit: Commit = {
  sha: 'abc',
  shortSha: 'abc',
  summary: 'First commit',
  body: '',
  parentShas: [],
  tags: [],
  author: { name: 'Test', email: 'test@example.com', date: 1, tzOffset: 0 },
  committer: { name: 'Test', email: 'test@example.com', date: 1, tzOffset: 0 },
}
let running = false
let bridge: ReturnType<typeof installFakeBridge>
beforeEach(() => {
  setLanguage('ko')
  running = false
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
  useHubStore.setState({
    hubs,
    pushes: [],
    status: undefined,
    dialog: undefined,
    repoId: undefined,
  })
  useAppStore.setState({ repositories: [repo], selectedRepositoryId: undefined })
  bridge = installFakeBridge((channel, ...args) => {
    if (channel === 'hub:discovered') return hubs
    if (channel === 'hub:listRemoteRepositories') return args[0] === hubs[1].url ? [remote] : []
    if (channel === 'hub:createRemoteRepository') return { ...remote, name: args[1] }
    if (channel === 'git:clone' || channel === 'repos:open') return repo
    if (channel === 'hub:getSettings') return settings
    if (channel === 'hub:status')
      return { running, port: 8765, addresses: running ? [hubs[0].url] : [], repositoryCount: 1 }
    if (channel === 'hub:updateSettings') {
      running = Boolean((args[0] as HubSettings).enabled)
      return { ...settings, ...(args[0] as object) }
    }
    if (channel === 'hub:listLocalRepositories') return [remote]
    if (channel === 'hub:pushLog') return []
    if (channel === 'hub:remoteLog') return [commit]
    if (channel === 'hub:remoteCommitFiles') return [{ path: 'README.md', status: 'modified' }]
    if (channel === 'hub:remoteCommitDiff') return { kind: 'binary' }
    if (channel === 'dialog:pickDirectory') return 'C:/repos'
    if (channel === 'hub:addManual') return { ...hubs[1], url: args[0], id: args[0] }
  })
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})

it('opens the group menu and keeps the hub entry available before discovery', async () => {
  render(<HubGroupMenu />)
  fireEvent.click(screen.getByRole('button', { name: t('hub.groupMenu', { count: 2 }) }))
  fireEvent.click(screen.getByRole('button', { name: t('hub.host') }))
  expect(await screen.findByRole('dialog', { name: t('hub.title') })).toBeTruthy()
})
it('selects a hub, loads its repositories, chooses a destination and clones with progress', async () => {
  useHubStore.getState().open('clone')
  render(<HubDialogs />)
  fireEvent.click(screen.getByRole('option', { name: /Lab/ }))
  expect(await screen.findByRole('option', { name: /team.*Shared project/ })).toBeTruthy()
  expect(bridge.invoke).toHaveBeenCalledWith('hub:listRemoteRepositories', hubs[1].url)
  fireEvent.click(screen.getByRole('button', { name: t('hub.chooseFolder') }))
  await waitFor(() =>
    expect((screen.getByLabelText(t('hub.destination')) as HTMLInputElement).value).toBe(
      'C:/repos/team'
    )
  )
  fireEvent.click(screen.getByRole('button', { name: t('hub.cloneAction') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:clone', {
      url: remote.url,
      path: 'C:/repos/team',
      opId: expect.any(String),
    })
  )
  await waitFor(() => expect(useAppStore.getState().selectedRepositoryId).toBe('cloned'))
})
it('creates a remote repository in the selected hub', async () => {
  useHubStore.getState().open('clone')
  render(<HubDialogs />)
  fireEvent.click(screen.getByRole('option', { name: /Lab/ }))
  await screen.findByRole('option', { name: /team.*Shared project/ })
  fireEvent.click(screen.getByRole('button', { name: t('hub.create') }))
  fireEvent.change(screen.getByLabelText(t('hub.name')), { target: { value: 'new-team' } })
  const fieldset = screen.getByRole('group', { name: t('hub.create') })
  fireEvent.click(within(fieldset).getByRole('button', { name: t('hub.create') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(
      'hub:createRemoteRepository',
      hubs[1].url,
      'new-team',
      undefined
    )
  )
})
it('publishes with the folder name and selected hub using its own store', async () => {
  useHubStore.getState().open('publish', repo.id)
  render(<HubDialogs />)
  expect((screen.getByLabelText(t('hub.name')) as HTMLInputElement).value).toBe('team')
  fireEvent.click(screen.getByRole('option', { name: /Lab/ }))
  fireEvent.change(screen.getByLabelText(t('hub.description')), {
    target: { value: 'Published project' },
  })
  fireEvent.click(screen.getByRole('button', { name: t('hub.publishAction') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('hub:publish', repo.id, {
      hubUrl: hubs[1].url,
      name: 'team',
      description: 'Published project',
      opId: expect.any(String),
    })
  )
})
it('loads remote history, files and a read-only diff without cloning', async () => {
  render(<RemoteHistory url={hubs[1].url} repository="team" />)
  expect(await screen.findByRole('option', { name: /First commit/ })).toBeTruthy()
  expect(await screen.findByRole('option', { name: 'README.md' })).toBeTruthy()
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(
      'hub:remoteCommitDiff',
      hubs[1].url,
      'team',
      'abc',
      'README.md'
    )
  )
  expect(bridge.invoke).not.toHaveBeenCalledWith('git:clone', expect.anything())
})
it('starts and stops the host, shows addresses and receives push events', async () => {
  useHubStore.getState().open('host')
  render(<HubDialogs />)
  fireEvent.click(await screen.findByRole('button', { name: t('hub.start') }))
  await screen.findByText(hubs[0].url)
  expect(bridge.invoke).toHaveBeenCalledWith(
    'hub:updateSettings',
    expect.objectContaining({ enabled: true })
  )
  act(() =>
    bridge.emit('hub:pushReceived', {
      at: Date.now(),
      repository: 'incoming-project',
      ref: 'refs/heads/main',
      oldSha: '',
      newSha: 'abc',
      clientAddress: '192.168.0.20',
      clientHost: 'Teammate-PC',
    })
  )
  expect(screen.getByText(/incoming-project.*refs\/heads\/main.*Teammate-PC/)).toBeTruthy()
  act(() =>
    bridge.emit('hub:statusChanged', {
      running: true,
      port: 8765,
      addresses: ['http://192.168.0.9:8765'],
      repositoryCount: 2,
    })
  )
  expect(screen.getByText('http://192.168.0.9:8765')).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: t('hub.stop') }))
  await screen.findByRole('button', { name: t('hub.start') })
  expect(bridge.invoke).toHaveBeenCalledWith(
    'hub:updateSettings',
    expect.objectContaining({ enabled: false })
  )
})
it('requires confirmation before trashing a host repository', async () => {
  useHubStore.getState().open('host')
  render(<HubDialogs />)
  fireEvent.click(await screen.findByRole('button', { name: t('hub.trash') }))
  expect(bridge.invoke).not.toHaveBeenCalledWith('hub:deleteLocalRepository', expect.anything())
  fireEvent.click(screen.getByRole('button', { name: t('changesView.discardConfirm') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('hub:deleteLocalRepository', 'team')
  )
})
it('cancels trash confirmation without saving settings or deleting a repository', async () => {
  useHubStore.getState().open('host')
  render(<HubDialogs />)
  fireEvent.click(await screen.findByRole('button', { name: t('hub.trash') }))
  fireEvent.click(
    within(screen.getByRole('alertdialog')).getByRole('button', { name: t('changesView.cancel') })
  )
  expect(screen.queryByRole('alertdialog')).toBeNull()
  expect(bridge.invoke).not.toHaveBeenCalledWith('hub:deleteLocalRepository', expect.anything())
  expect(bridge.invoke).not.toHaveBeenCalledWith('hub:updateSettings', expect.anything())
})

it('filters clone progress by opId while keeping duplicate submissions disabled', async () => {
  let resolveClone!: (value: unknown) => void
  const progressBridge = installFakeBridge((channel) => {
    if (channel === 'hub:discovered') return hubs
    if (channel === 'hub:listRemoteRepositories') return [remote]
    if (channel === 'git:clone')
      return new Promise((resolve) => {
        resolveClone = resolve
      })
    if (channel === 'repos:open') return repo
  })
  useHubStore.getState().open('clone')
  render(<HubDialogs />)
  await screen.findByRole('option', { name: /team.*Shared project/ })
  fireEvent.change(screen.getByLabelText(t('hub.destination')), {
    target: { value: 'C:/repos/team' },
  })
  fireEvent.click(screen.getByRole('button', { name: t('hub.cloneAction') }))
  const progress = await screen.findByRole('progressbar')
  const input = progressBridge.invoke.mock.calls.find(
    ([channel]) => channel === 'git:clone'
  )![1] as { opId: string }
  act(() =>
    progressBridge.emit('git:progress', {
      opId: 'other',
      progress: { kind: 'clone', title: '', value: 0.9 },
    })
  )
  expect(progress.getAttribute('value')).toBe('0')
  act(() =>
    progressBridge.emit('git:progress', {
      opId: input.opId,
      progress: { kind: 'clone', title: '', value: 0.5 },
    })
  )
  expect(progress.getAttribute('value')).toBe('0.5')
  expect(
    (screen.getByRole('button', { name: t('common.loading') }) as HTMLButtonElement).disabled
  ).toBe(true)
  await act(async () => resolveClone(repo))
})

it('shows a typed error and details when publication fails', async () => {
  installFakeBridge((channel) => {
    if (channel === 'hub:discovered') return hubs
    if (channel === 'hub:publish') throw { kind: 'network', message: 'offline' }
  })
  useHubStore.getState().open('publish', repo.id)
  render(<HubDialogs />)
  fireEvent.click(screen.getByRole('button', { name: t('hub.publishAction') }))
  expect(await screen.findByRole('alert')).toBeTruthy()
  expect(screen.getByText(t('hub.networkError'))).toBeTruthy()
  expect(screen.getByText('offline')).toBeTruthy()
})

it('ignores a late repository response from the previously selected hub', async () => {
  let resolveOffice!: (value: unknown) => void
  installFakeBridge((channel, url) => {
    if (channel === 'hub:discovered') return hubs
    if (channel === 'hub:listRemoteRepositories')
      return url === hubs[0].url
        ? new Promise((resolve) => {
            resolveOffice = resolve
          })
        : [remote]
  })
  useHubStore.getState().open('clone')
  render(<HubDialogs />)
  fireEvent.click(screen.getByRole('option', { name: /Lab/ }))
  await screen.findByRole('option', { name: /team.*Shared project/ })
  await act(async () => resolveOffice([{ name: 'stale', url: 'http://localhost/stale.git' }]))
  expect(screen.queryByRole('option', { name: /stale/ })).toBeNull()
  expect(screen.getByRole('option', { name: /team.*Shared project/ })).toBeTruthy()
})

it('navigates hub lists with the keyboard and opens remote history from clone', async () => {
  useHubStore.getState().open('clone')
  render(<HubDialogs />)
  const list = screen.getByRole('listbox', { name: t('hub.hubs') }).querySelector('[tabindex="0"]')!
  fireEvent.keyDown(list, { key: 'ArrowDown' })
  await screen.findByRole('option', { name: /team.*Shared project/ })
  fireEvent.click(screen.getByRole('button', { name: t('hub.history') }))
  expect(await screen.findByRole('option', { name: /First commit/ })).toBeTruthy()
  expect(bridge.invoke).toHaveBeenCalledWith('hub:remoteLog', hubs[1].url, 'team', { limit: 100 })
})

it('adds and removes a manual hub through the client contract', async () => {
  useHubStore.getState().open('manual')
  render(<HubDialogs />)
  fireEvent.click(screen.getByRole('button', { name: t('hub.remove') }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('hub:removeManual', hubs[1].id))
  fireEvent.change(screen.getByLabelText(t('hub.url')), { target: { value: '192.168.0.5:8765' } })
  fireEvent.click(screen.getByRole('button', { name: t('hub.add') }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('hub:addManual', '192.168.0.5:8765')
  )
})
