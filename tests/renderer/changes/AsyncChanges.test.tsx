// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { ChangesView } from '@renderer/components/changes/ChangesView'
import { useAppStore } from '@renderer/state/app-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { diff, status } from './fixtures'
beforeEach(() => {
  useAppStore.setState({ selectedRepositoryId: 'one' })
  useRepoStore.setState({ repoId: 'one', status, error: undefined })
  useChangesStore.setState({ repositories: {} })
})
afterEach(cleanup)
it('ignores an outdated working diff after selecting another file', async () => {
  let resolveFirst!: (value: unknown) => void
  const bridge = vi.fn((_: string, _repo: string, path: string) =>
    path === 'src/a.ts'
      ? new Promise((resolve) => {
          resolveFirst = resolve
        })
      : Promise.resolve({ ok: true, value: { kind: 'binary' } })
  )
  Object.defineProperty(window, 'ghp', {
    configurable: true,
    value: { invoke: bridge, on: vi.fn() },
  })
  render(<ChangesView />)
  await waitFor(() => expect(bridge).toHaveBeenCalled())
  fireEvent.click(screen.getByTitle('b.ts'))
  await screen.findByText(/바이너리/)
  await act(async () => resolveFirst({ ok: true, value: diff }))
  expect(screen.queryByText('+new')).toBeNull()
  expect(screen.getByText(/바이너리/)).toBeTruthy()
})
it('isolates selections and closes menus when switching repositories', async () => {
  Object.defineProperty(window, 'ghp', {
    configurable: true,
    value: { invoke: vi.fn(async () => ({ ok: true, value: diff })), on: vi.fn() },
  })
  render(<ChangesView />)
  await screen.findByText('+new')
  fireEvent.click(screen.getByLabelText('src/a.ts 커밋에 포함'))
  fireEvent.contextMenu(screen.getByTitle('b.ts'))
  act(() => {
    useAppStore.setState({ selectedRepositoryId: 'two' })
    useRepoStore.setState({ repoId: 'two', status: { ...status } })
  })
  expect(screen.queryByRole('menu')).toBeNull()
  expect((screen.getByLabelText('src/a.ts 커밋에 포함') as HTMLInputElement).checked).toBe(true)
  act(() => {
    useAppStore.setState({ selectedRepositoryId: 'one' })
    useRepoStore.setState({ repoId: 'one', status: { ...status } })
  })
  expect((screen.getByLabelText('src/a.ts 커밋에 포함') as HTMLInputElement).checked).toBe(false)
})
