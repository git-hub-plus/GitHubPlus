// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { beforeEach, afterEach, expect, it } from 'vitest'
import { Toolbar } from '../../../src/renderer/src/components/Toolbar'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useHubStore } from '../../../src/renderer/src/state/hub-store'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { repository, status } from '../app/test-utils'
const server = {
  running: true,
  port: 8765,
  addresses: ['http://localhost:8765'],
  repositoryCount: 3,
}
const discovered = {
  id: 'hub',
  url: 'http://localhost:8765',
  name: 'hub',
  online: true,
  lastSeen: 0,
  manual: false,
}
let bridge: ReturnType<typeof installFakeBridge>
beforeEach(() => {
  useAppStore.setState({ repositories: [repository], selectedRepositoryId: 'repo' })
  useRepoStore.setState({ repoId: 'repo', status })
  useHubStore.setState({ hubs: [], status: undefined, dialog: undefined })
  bridge = installFakeBridge((channel) =>
    channel === 'hub:status'
      ? { ...server, running: false }
      : channel === 'git:remotes'
        ? [{ name: 'origin', url: 'http://localhost:8765/repo.git' }]
        : []
  )
})
afterEach(cleanup)
it('loads local host status and opens the existing host dialog', async () => {
  bridge = installFakeBridge((channel) => (channel === 'hub:status' ? server : []))
  render(<Toolbar />)
  fireEvent.click(await screen.findByRole('button', { name: '허브 실행 중' }))
  expect(useHubStore.getState().dialog).toBe('host')
  expect(screen.queryByText('허브 연결됨')).toBeNull()
})
it('handles live host status and prevents a stale initial reply from overwriting it', async () => {
  let resolve!: (value: unknown) => void
  bridge = installFakeBridge(
    () =>
      new Promise((done) => {
        resolve = done
      })
  )
  render(<Toolbar />)
  await waitFor(() => expect(resolve).toBeDefined())
  act(() => bridge.emit('hub:statusChanged', server))
  await act(async () => resolve({ ...server, running: false }))
  expect(screen.getByRole('button', { name: '허브 실행 중' })).toBeTruthy()
  act(() => bridge.emit('hub:statusChanged', { ...server, running: false }))
  expect(screen.queryByRole('button', { name: '허브 실행 중' })).toBeNull()
})
it('uses the matching hub online state and updates live', async () => {
  useAppStore.setState({ repositories: [{ ...repository, group: 'hub' }] })
  useHubStore.setState({ hubs: [discovered] })
  render(<Toolbar />)
  await screen.findByText('허브 연결됨')
  act(() => useHubStore.setState({ hubs: [{ ...discovered, online: false }] }))
  expect(screen.getByText('허브 오프라인')).toBeTruthy()
  expect(screen.queryByRole('button', { name: '허브 실행 중' })).toBeNull()
})
it('does not match a different remote host or retain state after repository switching', async () => {
  useAppStore.setState({
    repositories: [{ ...repository, group: 'hub', remoteUrl: 'http://localhost:87650/repo.git' }],
  })
  useHubStore.setState({ hubs: [discovered] })
  bridge = installFakeBridge(() => undefined)
  render(<Toolbar />)
  expect(screen.getByText('허브 오프라인')).toBeTruthy()
  act(() => useAppStore.setState({ repositories: [repository] }))
  expect(screen.queryByText('허브 오프라인')).toBeNull()
})
