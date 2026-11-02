// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ChangesView } from '@renderer/components/changes/ChangesView'
import { useAppStore } from '@renderer/state/app-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { selectNone, withToggledLine, selectAll } from '@shared/models/diff-selection'
import { diff, status } from './fixtures'

const bridge = vi.fn(async (channel: string) => ({
  ok: true,
  value: channel === 'git:workingDiff' ? diff : channel === 'git:status' ? status : 'sha',
}))
beforeEach(() => {
  bridge.mockClear()
  Object.defineProperty(window, 'ghp', {
    configurable: true,
    value: { invoke: bridge as unknown as typeof window.ghp.invoke, on: vi.fn(() => () => {}) },
  })
  useAppStore.setState({ selectedRepositoryId: 'repo' })
  useRepoStore.setState({ repoId: 'repo', status, loading: false, error: undefined })
  useChangesStore.setState({ repositories: {} })
})
afterEach(cleanup)
describe('changes view', () => {
  it('renders file statuses and all/partial/none checkboxes, preserving selections after refresh', async () => {
    render(<ChangesView />)
    expect(screen.getByText('2개 파일 변경됨')).toBeTruthy()
    expect(screen.getByText('old.ts')).toBeTruthy()
    await screen.findByText('+new')
    const file = screen.getByLabelText('src/a.ts 커밋에 포함') as HTMLInputElement
    expect(file.checked).toBe(true)
    fireEvent.click(screen.getByLabelText('diff 1번 줄 포함 전환'))
    expect(file.indeterminate).toBe(true)
    fireEvent.click(file)
    expect(file.checked).toBe(true)
    fireEvent.click(file)
    expect(file.checked).toBe(false)
    expect(file.indeterminate).toBe(false)
    fireEvent.click(screen.getByTitle('b.ts'))
    act(() =>
      useRepoStore.setState({
        status: { ...status, files: [...status.files, { ...status.files[0], path: 'new.ts' }] },
      })
    )
    expect((screen.getByLabelText('src/a.ts 커밋에 포함') as HTMLInputElement).checked).toBe(false)
    expect((screen.getByLabelText('new.ts 커밋에 포함') as HTMLInputElement).checked).toBe(true)
    expect(useChangesStore.getState().repositories.repo.path).toBe('b.ts')
    act(() => useRepoStore.setState({ status: { ...status, files: [status.files[1]] } }))
    expect(useChangesStore.getState().repositories.repo.selections['src/a.ts']).toBeUndefined()
  })
  it('validates commit and sends partial selections, description and amend via Ctrl+Enter', async () => {
    render(<ChangesView />)
    const button = screen.getByRole('button', { name: 'main에 커밋' }) as HTMLButtonElement
    expect(button.disabled).toBe(true)
    await screen.findByText('+new')
    act(() => {
      useChangesStore
        .getState()
        .setSelection('repo', 'src/a.ts', withToggledLine(selectAll([1, 2]), 1))
      useChangesStore.getState().setSelection('repo', 'b.ts', selectNone())
    })
    fireEvent.change(screen.getByLabelText('요약 (필수)'), { target: { value: 'Fix changes' } })
    fireEvent.change(screen.getByLabelText('설명'), { target: { value: 'Details\nSecond line' } })
    fireEvent.click(screen.getByLabelText('마지막 커밋 수정(amend)'))
    expect(button.disabled).toBe(false)
    const selection = useChangesStore.getState().repositories.repo.selections['src/a.ts']
    fireEvent.keyDown(screen.getByLabelText('요약 (필수)'), { key: 'Enter', ctrlKey: true })
    await waitFor(() =>
      expect(bridge).toHaveBeenCalledWith('git:commit', 'repo', {
        summary: 'Fix changes',
        description: 'Details\nSecond line',
        amend: true,
        files: [{ path: 'src/a.ts', selection }],
      })
    )
    await waitFor(() => expect(bridge).toHaveBeenCalledWith('git:status', 'repo'))
    expect((screen.getByLabelText('요약 (필수)') as HTMLInputElement).value).toBe('')
  })
  it('disables commit without included files, warns on long summary and handles empty state', async () => {
    render(<ChangesView />)
    await screen.findByText('+new')
    fireEvent.change(screen.getByLabelText('요약 (필수)'), { target: { value: 'x'.repeat(73) } })
    expect(screen.getByText(/72자를 넘었습니다/)).toBeTruthy()
    fireEvent.click(screen.getByLabelText('전체 선택'))
    expect(
      (screen.getByRole('button', { name: 'main에 커밋' }) as HTMLButtonElement).disabled
    ).toBe(true)
    act(() => useRepoStore.setState({ status: { ...status, files: [] } }))
    expect(screen.getByText('변경 사항이 없습니다')).toBeTruthy()
  })
  it('requires confirmation before discard and supports copying the path', async () => {
    Object.defineProperty(navigator, 'clipboard', {
      configurable: true,
      value: { writeText: vi.fn().mockResolvedValue(undefined) },
    })
    render(<ChangesView />)
    fireEvent.contextMenu(screen.getByTitle('b.ts'))
    fireEvent.click(screen.getByRole('menuitem', { name: '경로 복사' }))
    expect(navigator.clipboard.writeText).toHaveBeenCalledWith('b.ts')
    fireEvent.contextMenu(screen.getByTitle('b.ts'))
    fireEvent.click(screen.getByRole('menuitem', { name: '변경 사항 버리기…' }))
    expect(bridge.mock.calls.some(([channel]) => channel === 'git:discard')).toBe(false)
    fireEvent.click(screen.getByRole('button', { name: '변경 사항 버리기' }))
    await waitFor(() => expect(bridge).toHaveBeenCalledWith('git:discard', 'repo', ['b.ts']))
  })
  it('shows IPC error detail and keeps commit input on failure', async () => {
    bridge.mockImplementationOnce(
      async () =>
        ({
          ok: false,
          error: { kind: 'unknown', message: 'broken', detail: 'raw stderr' },
        }) as never
    )
    render(<ChangesView />)
    await screen.findByRole('alert')
    expect(screen.getByText(/raw stderr/)).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: '다시 시도' }))
    await screen.findByText('+new')
    fireEvent.change(screen.getByLabelText('요약 (필수)'), { target: { value: 'Keep me' } })
    bridge.mockImplementationOnce(
      async () => ({ ok: false, error: { kind: 'unknown', message: 'commit failed' } }) as never
    )
    fireEvent.click(screen.getByRole('button', { name: 'main에 커밋' }))
    await screen.findByRole('alert')
    expect((screen.getByLabelText('요약 (필수)') as HTMLInputElement).value).toBe('Keep me')
  })
})
