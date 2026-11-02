// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { Sidebar } from '../../../src/renderer/src/components/Sidebar'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { useDialogStore } from '../../../src/renderer/src/state/dialog-store'
import { setup, repository, status } from './test-utils'

let bridge: ReturnType<typeof setup>
beforeEach(() => {
  bridge = setup()
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
it('opens the three repository dialogs from the add menu', () => {
  render(<Sidebar />)
  fireEvent.click(screen.getByRole('button', { name: '+ 추가' }))
  expect(screen.getByRole('button', { name: '새 저장소' })).toBeTruthy()
  expect(screen.getByRole('button', { name: '저장소 복제' })).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: '로컬 저장소 추가' }))
  expect(useDialogStore.getState().kind).toBe('add')
})
it('shows status only for the selected repository and supports keyboard selection', async () => {
  useAppStore.setState({
    repositories: [repository, { ...repository, id: 'second', name: 'second' }],
  })
  useRepoStore.setState({
    status: {
      ...status,
      ahead: 2,
      behind: 1,
      files: [{ path: 'x', status: { kind: 'Untracked' } }],
    } as never,
  })
  render(<Sidebar />)
  const first = screen.getByRole('option', { name: /example/ })
  const second = screen.getByRole('option', { name: 'second' })
  expect(first.textContent).toContain('앞섬 2')
  expect(second.textContent).toBe('second')
  first.focus()
  fireEvent.keyDown(first, { key: 'ArrowDown' })
  expect(document.activeElement).toBe(second)
  fireEvent.keyDown(second, { key: 'Enter' })
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('repos:open', 'second'))
})
it('updates repository pinning', async () => {
  bridge.invoke.mockResolvedValueOnce({ ok: true, value: { ...repository, pinned: true } })
  render(<Sidebar />)
  fireEvent.contextMenu(screen.getByRole('option'))
  fireEvent.click(screen.getByRole('button', { name: '고정' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('repos:update', 'repo', { pinned: true })
  )
})
it('edits an alias using a temporary owned dialog', async () => {
  bridge.invoke.mockResolvedValueOnce({ ok: true, value: { ...repository, alias: 'Work' } })
  render(<Sidebar />)
  fireEvent.contextMenu(screen.getByRole('option'))
  fireEvent.click(screen.getByRole('button', { name: '별칭 바꾸기' }))
  fireEvent.change(screen.getByLabelText('이름'), { target: { value: 'Work' } })
  fireEvent.click(screen.getByRole('button', { name: '확인' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('repos:update', 'repo', { alias: 'Work' })
  )
})
it('requires confirmation before removing a repository', async () => {
  render(<Sidebar />)
  fireEvent.contextMenu(screen.getByRole('option'))
  fireEvent.click(screen.getByRole('button', { name: '목록에서 제거' }))
  expect(bridge.invoke).not.toHaveBeenCalledWith('repos:remove', 'repo')
  fireEvent.click(screen.getByRole('button', { name: '확인' }))
  await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('repos:remove', 'repo'))
})
