// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { t } from '@shared/i18n'
import { AppFileStatusKind, type RepoStatus } from '@shared/models/status'
import { DropZone } from '@renderer/components/dropzone/DropZone'
import { useAppStore } from '@renderer/state/app-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { useToastStore } from '@renderer/state/toast-store'
import { installFakeBridge } from '../helpers/fake-bridge'

const repository = {
  id: 'repo',
  name: 'repo',
  path: 'C:/repo',
  group: 'local' as const,
  pinned: false,
  available: true,
  addedAt: 0,
}
const status: RepoStatus = {
  ahead: 0,
  behind: 0,
  stashCount: 0,
  files: [{ path: 'docs/new.txt', status: { kind: AppFileStatusKind.Untracked } }],
}
const dataTransfer = { types: ['Files'], files: [new File(['new'], 'new.txt')], dropEffect: 'none' }
beforeEach(() => {
  HTMLDialogElement.prototype.showModal = function () {
    this.open = true
  }
  HTMLDialogElement.prototype.close = vi.fn()
  useAppStore.setState({ selectedRepositoryId: 'repo', repositories: [repository], tab: 'history' })
  useRepoStore.setState({ repoId: 'repo', status, loading: false })
  useChangesStore.setState({
    repositories: { repo: { path: 'docs/selected.txt', selections: {} } },
    messageDrafts: {},
  })
  useToastStore.setState({ toasts: [] })
})
afterEach(cleanup)

function bridge() {
  const fake = installFakeBridge((channel) => {
    if (channel === 'files:copyIntoRepository')
      return { copied: ['docs/new.txt'], skipped: ['docs/old.txt'] }
    if (channel === 'git:status') return status
    if (channel === 'dialog:pickDirectory') return 'C:/repo/docs'
    return undefined
  })
  window.ghp.getPathForFile = vi.fn(() => 'C:/source/new.txt')
  return fake
}
function drop() {
  fireEvent.dragEnter(window, { dataTransfer })
  expect(screen.getByText(t('ai.drop.overlay'))).toBeTruthy()
  fireEvent.drop(window, { dataTransfer })
}

describe('window file drop', () => {
  it('suggests selected folder, copies files, selects results and notifies with counts', async () => {
    const fake = bridge()
    render(<DropZone />)
    drop()
    expect(screen.queryByText(t('ai.drop.overlay'))).toBeNull()
    expect((screen.getByLabelText(t('ai.drop.target')) as HTMLInputElement).value).toBe('docs')
    fireEvent.click(screen.getByRole('button', { name: t('ai.drop.copy') }))
    await screen.findByText(t('ai.drop.result', { copied: 1, skipped: 1 }))
    await waitFor(() =>
      expect(useChangesStore.getState().repositories.repo.path).toBe('docs/new.txt')
    )
    expect(fake.invoke).toHaveBeenCalledWith('files:copyIntoRepository', 'repo', {
      sources: ['C:/source/new.txt'],
      targetDirectory: 'docs',
    })
    expect(useAppStore.getState().tab).toBe('changes')
    expect(
      useChangesStore.getState().repositories.repo.selections['docs/new.txt'].defaultSelectionType
    ).toBe('all')
  })
  it('supports folder picker and committing only copied files', async () => {
    const fake = bridge()
    render(<DropZone />)
    drop()
    fireEvent.click(screen.getByRole('button', { name: t('ai.drop.chooseFolder') }))
    await waitFor(() =>
      expect((screen.getByLabelText(t('ai.drop.target')) as HTMLInputElement).value).toBe(
        'C:/repo/docs'
      )
    )
    fireEvent.click(screen.getByLabelText(t('ai.drop.commitNow')))
    fireEvent.change(screen.getByLabelText(t('ai.drop.summary')), { target: { value: 'Add docs' } })
    fireEvent.click(screen.getByRole('button', { name: t('ai.drop.copy') }))
    await waitFor(() =>
      expect(fake.invoke).toHaveBeenCalledWith(
        'git:commit',
        'repo',
        expect.objectContaining({
          summary: 'Add docs',
          files: [{ path: 'docs/new.txt', selection: expect.any(Object) }],
        })
      )
    )
  })
  it('ignores text drags and drags without a selected repository', () => {
    bridge()
    render(<DropZone />)
    fireEvent.dragEnter(window, { dataTransfer: { types: ['text/plain'] } })
    expect(screen.queryByRole('status')).toBeNull()
    act(() => useAppStore.setState({ selectedRepositoryId: undefined }))
    fireEvent.dragEnter(window, { dataTransfer })
    expect(screen.queryByRole('status')).toBeNull()
  })
  it('rejects files whose native path is unavailable', async () => {
    const fake = bridge()
    window.ghp.getPathForFile = () => ''
    render(<DropZone />)
    fireEvent.drop(window, { dataTransfer })
    expect(fake.invoke).not.toHaveBeenCalled()
    expect(useToastStore.getState().toasts[0].kind).toBe('error')
  })
})
