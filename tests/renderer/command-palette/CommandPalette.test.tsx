// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it } from 'vitest'
import { setLanguage } from '@shared/i18n'
import { CommandPalette } from '../../../src/renderer/src/components/command-palette/CommandPalette'
import { fuzzyScore, registerCommand } from '../../../src/renderer/src/lib/commands'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useDialogStore } from '../../../src/renderer/src/state/dialog-store'
import { usePaletteStore } from '../../../src/renderer/src/state/palette-store'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { useSyncStore } from '../../../src/renderer/src/state/sync-store'
import { installFakeBridge } from '../helpers/fake-bridge'
import { repository, status } from '../app/test-utils'

let bridge: ReturnType<typeof installFakeBridge>
beforeEach(() => {
  setLanguage('ko')
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
  useAppStore.setState({
    repositories: [repository, { ...repository, id: 'two', name: 'second' }],
    selectedRepositoryId: 'repo',
    tab: 'changes',
    preferencesOpen: false,
  })
  useRepoStore.setState({ repoId: 'repo', status })
  useSyncStore.setState({ active: undefined })
  usePaletteStore.getState().close()
  useDialogStore.getState().close()
  bridge = installFakeBridge((channel) =>
    channel === 'git:branches'
      ? [{ name: 'feature/topic', type: 'local', isCurrent: false, tipSha: 'a' }]
      : channel === 'git:status'
        ? status
        : undefined
  )
})
afterEach(cleanup)
function open() {
  render(<CommandPalette />)
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true })
}
function search(value: string) {
  fireEvent.change(screen.getByRole('searchbox'), { target: { value } })
}
it('ranks exact, contiguous and scattered subsequences and rejects nonmatches', () => {
  expect(fuzzyScore('main', 'main')).toBeGreaterThan(fuzzyScore('domain', 'main')!)
  expect(fuzzyScore('feature', 'feat')).toBeGreaterThan(fuzzyScore('far east tree', 'feat')!)
  expect(fuzzyScore('main', 'xyz')).toBeUndefined()
  expect(fuzzyScore('Feature', 'FEAT')).toBeDefined()
})
it('opens from menu, searches, moves selection, executes with Enter and restores focus', async () => {
  const trigger = document.createElement('button')
  document.body.append(trigger)
  trigger.focus()
  render(<CommandPalette />)
  act(() => bridge.emit('menu:command', 'command-palette'))
  const input = screen.getByRole('searchbox')
  expect(document.activeElement).toBe(input)
  fireEvent.keyDown(input, { key: 'ArrowDown' })
  fireEvent.keyDown(input, { key: 'Enter' })
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('repos:open', 'two'))
  expect(document.activeElement).toBe(trigger)
  trigger.remove()
})
it('checks out a fuzzy branch match with progress id and refreshes', async () => {
  open()
  await screen.findByRole('button', { name: '브랜치: feature/topic' })
  search('ftpc')
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:checkout', 'repo', 'feature/topic', {
      opId: expect.any(String),
    })
  )
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('git:status', 'repo'))
})
it.each([
  ['가져오기', 'git:fetch'],
  ['풀', 'git:pull'],
  ['푸시', 'git:push'],
])('executes sync %s', async (query, channel) => {
  open()
  search(query)
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith(channel, 'repo', { opId: expect.any(String) })
  )
  await waitFor(() => expect(useSyncStore.getState().active).toBeUndefined())
})
it.each([
  ['저장소 추가', 'add'],
  ['저장소 만들기', 'create'],
  ['저장소 복제', 'clone'],
  ['새 브랜치', 'branch'],
])('opens dialog %s', async (query, kind) => {
  open()
  search(query)
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() => expect(useDialogStore.getState().kind).toBe(kind))
})
it('switches tabs and preferences and closes on Escape without an action', async () => {
  open()
  search('히스토리')
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() => expect(useAppStore.getState().tab).toBe('history'))
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true })
  search('환경설정')
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() => expect(useAppStore.getState().preferencesOpen).toBe(true))
  fireEvent.keyDown(window, { key: 'k', ctrlKey: true })
  search('xyz')
  expect(screen.getByText('일치하는 명령이 없습니다.')).toBeTruthy()
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Escape' })
  expect(screen.queryByRole('dialog')).toBeNull()
})
it('updates registered commands while mounted and disposes them safely', async () => {
  open()
  let calls = 0
  let dispose!: () => void
  act(() => {
    dispose = registerCommand({
      id: 'extension',
      label: 'lfs.title',
      run() {
        calls++
      },
    })
  })
  search('LFS·서브모듈')
  fireEvent.keyDown(screen.getByRole('searchbox'), { key: 'Enter' })
  await waitFor(() => expect(calls).toBe(1))
  act(dispose)
})
