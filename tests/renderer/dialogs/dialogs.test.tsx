// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import {
  RepositoryDialogs,
  validBranch,
} from '../../../src/renderer/src/components/dialogs/RepositoryDialogs'
import { useDialogStore } from '../../../src/renderer/src/state/dialog-store'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { setup } from '../app/test-utils'

let bridge: ReturnType<typeof setup>
beforeEach(() => {
  bridge = setup()
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
it('normalizes owner/repo and sends clone destination and opId, then selects the clone', async () => {
  useDialogStore.getState().open('clone')
  render(<RepositoryDialogs />)
  fireEvent.change(screen.getByLabelText('저장소 URL'), { target: { value: ' owner/example ' } })
  fireEvent.change(screen.getByLabelText('복제할 폴더 (전체 경로)'), {
    target: { value: 'C:/repos/example' },
  })
  fireEvent.click(screen.getByRole('button', { name: '저장소 복제' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:clone', {
      url: 'https://github.com/owner/example.git',
      path: 'C:/repos/example',
      opId: expect.any(String),
    })
  )
  await waitFor(() => expect(useAppStore.getState().selectedRepositoryId).toBe('clone'))
})
it('offers creation after not-a-repository, keeping the chosen folder', async () => {
  useDialogStore.getState().open('add')
  bridge.invoke.mockResolvedValueOnce({
    ok: false,
    error: { kind: 'not-a-repository', message: 'not git' },
  } as never)
  render(<RepositoryDialogs />)
  fireEvent.click(screen.getByRole('button', { name: '로컬 저장소 추가' }))
  fireEvent.click(await screen.findByRole('button', { name: '여기에 새 저장소 만들기' }))
  expect((screen.getByLabelText('위치') as HTMLInputElement).value).toBe('C:/')
  expect((screen.getByLabelText('이름') as HTMLInputElement).value).toBe('repos')
  expect(screen.getByRole('dialog', { name: '새 저장소' })).toBeTruthy()
})
it('creates a repository with default directory and README preference', async () => {
  useDialogStore.getState().open('create')
  render(<RepositoryDialogs />)
  expect(document.activeElement).toBe(screen.getByLabelText('이름'))
  fireEvent.change(screen.getByLabelText('이름'), { target: { value: 'demo' } })
  fireEvent.click(screen.getByRole('checkbox'))
  fireEvent.click(screen.getByRole('button', { name: '새 저장소' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('repos:create', {
      name: 'demo',
      parentDirectory: 'C:/repos',
      addReadme: false,
    })
  )
})
it('normalizes branch spaces and blocks invalid names', async () => {
  useDialogStore.getState().open('branch')
  render(<RepositoryDialogs />)
  fireEvent.change(screen.getByLabelText('이름'), { target: { value: 'new branch' } })
  expect((screen.getByLabelText('이름') as HTMLInputElement).value).toBe('new-branch')
  fireEvent.click(screen.getByRole('button', { name: '새 브랜치…' }))
  await waitFor(() =>
    expect(bridge.invoke).toHaveBeenCalledWith('git:createBranch', 'repo', {
      name: 'new-branch',
      startPoint: 'main',
      checkout: true,
    })
  )
})
it.each(['a..b', 'bad:name', 'a.lock', 'a/.b', '@', '/bad', 'bad/', '-bad', 'bad[', 'bad\\name'])(
  'rejects invalid branch %s',
  (value) => expect(validBranch(value)).toBe(false)
)
it('closes on the native dialog cancel event', () => {
  useDialogStore.getState().open('add')
  render(<RepositoryDialogs />)
  act(() =>
    screen
      .getByRole('dialog')
      .dispatchEvent(new Event('cancel', { bubbles: true, cancelable: true }))
  )
  expect(screen.queryByRole('dialog')).toBeNull()
})
