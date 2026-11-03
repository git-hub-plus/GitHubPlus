// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { App } from '../../../src/renderer/src/App'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { usePaletteStore } from '../../../src/renderer/src/state/palette-store'
import { useToastStore, showToast } from '../../../src/renderer/src/state/toast-store'
import { GhpError } from '@shared/errors'
import { setup } from './test-utils'

vi.mock('../../../src/renderer/src/components/Workspace', () => ({ Workspace: () => null }))
vi.mock('../../../src/renderer/src/hooks/use-applied-theme', () => ({
  useAppliedTheme: () => undefined,
}))
let bridge: ReturnType<typeof setup>
beforeEach(() => {
  usePaletteStore.setState({ open: false })
  bridge = setup()
  vi.spyOn(useAppStore.getState(), 'init').mockResolvedValue()
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
it.each([
  ['add-repository', '로컬 저장소 추가'],
  ['create-repository', '새 저장소'],
  ['clone-repository', '저장소 복제'],
  ['new-branch', '새 브랜치…'],
  ['about', 'GitHub+ 정보'],
] as const)('opens %s from native menu', async (command, title) => {
  render(<App />)
  act(() => bridge.emit('menu:command', command))
  expect(screen.getByRole('dialog', { name: title })).toBeTruthy()
  if (command === 'about') await screen.findByText('GitHub+ 0.1.0')
})
it('keeps preferences and tab commands, and opens the command palette', () => {
  render(<App />)
  act(() => bridge.emit('menu:command', 'show-history'))
  expect(useAppStore.getState().tab).toBe('history')
  act(() => bridge.emit('menu:command', 'show-changes'))
  expect(useAppStore.getState().tab).toBe('changes')
  act(() => bridge.emit('menu:command', 'command-palette'))
  expect(screen.getByRole('dialog', { name: '명령 팔레트' })).toBeTruthy()
  act(() => usePaletteStore.getState().close())
  act(() => bridge.emit('menu:command', 'open-preferences'))
  expect(useAppStore.getState().preferencesOpen).toBe(true)
})
it('focuses repository search with Ctrl+P', () => {
  useAppStore.setState({ preferencesOpen: false })
  render(<App />)
  fireEvent.keyDown(window, { key: 'p', ctrlKey: true })
  expect(document.activeElement).toBe(screen.getByRole('searchbox', { name: '저장소 검색' }))
})
it.each(['fetch', 'pull', 'push'] as const)(
  'routes the %s native command through synchronization',
  async (command) => {
    useAppStore.setState({ preferencesOpen: false })
    render(<App />)
    act(() => bridge.emit('menu:command', command))
    await waitFor(() =>
      expect(bridge.invoke).toHaveBeenCalledWith(`git:${command}`, 'repo', {
        opId: expect.any(String),
      })
    )
  }
)
it('shows persistent translated errors with detail and auto-dismisses success', async () => {
  vi.useFakeTimers()
  render(<App />)
  act(() => showToast(new GhpError({ kind: 'network', message: 'offline', detail: 'raw detail' })))
  expect(screen.getByRole('alert').textContent).toContain('네트워크 연결을 확인하세요.')
  expect(screen.getByText(/raw detail/)).toBeTruthy()
  act(() => showToast())
  act(() => vi.advanceTimersByTime(4000))
  expect(useToastStore.getState().toasts).toHaveLength(1)
  vi.useRealTimers()
  await waitFor(() => expect(screen.getByRole('alert')).toBeTruthy())
})
