// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import {
  RepositorySettingsDialog,
  RepositorySettingsHost,
} from '../../../src/renderer/src/components/repository-settings/RepositorySettingsDialog'
import { repositorySettingsMenuItems } from '../../../src/renderer/src/components/repository-settings/repository-menu'
import { LargeFileHint } from '../../../src/renderer/src/components/repository-settings/LargeFileHint'
import { installFakeBridge } from '../helpers/fake-bridge'
import { repository, setup, status } from '../app/test-utils'

let patterns: string[]
beforeEach(() => {
  setup()
  patterns = ['*.psd']
})
afterEach(() => {
  cleanup()
  vi.restoreAllMocks()
})
function bridge() {
  return installFakeBridge((channel, ...args) => {
    if (channel === 'git:remotes') return [{ name: 'origin', url: 'https://example.com/repo.git' }]
    if (channel === 'git:lfsStatus')
      return {
        available: true,
        installedInRepository: patterns.length > 0,
        trackedPatterns: patterns,
      }
    if (channel === 'git:submodules')
      return [{ path: 'vendor/demo', url: '../demo.git', status: 'uninitialized' }]
    if (channel === 'git:lfsTrack') {
      patterns = [...patterns, args[1] as string]
      return
    }
    if (channel === 'git:lfsUntrack') {
      patterns = patterns.filter((pattern) => pattern !== args[1])
      return
    }
    if (channel === 'git:status') return status
  })
}
it('opens repository settings from the sidebar extension and lists remotes', async () => {
  bridge()
  const view = render(<RepositorySettingsHost />)
  const menu = repositorySettingsMenuItems(repository)
  expect(menu).toHaveLength(1)
  act(() => menu[0].onSelect(repository))
  expect(await screen.findByText('https://example.com/repo.git')).toBeTruthy()
  fireEvent.click(screen.getByRole('button', { name: '닫기' }))
  expect(screen.queryByRole('dialog')).toBeNull()
  expect(repositorySettingsMenuItems({ ...repository, available: false })).toEqual([])
  view.unmount()
})
it('adds and removes LFS patterns and refreshes working-tree status', async () => {
  const fake = bridge()
  render(<RepositorySettingsDialog repository={repository} onClose={() => {}} />)
  fireEvent.click(screen.getByRole('tab', { name: 'Git LFS' }))
  expect(await screen.findByText('*.psd')).toBeTruthy()
  fireEvent.change(screen.getByLabelText('추적할 패턴'), { target: { value: '*.zip' } })
  fireEvent.click(screen.getByRole('button', { name: '패턴 추가' }))
  await screen.findByText('*.zip')
  await waitFor(() => expect(fake.invoke).toHaveBeenCalledWith('git:status', 'repo'))
  fireEvent.click(screen.getByRole('button', { name: '삭제 *.psd' }))
  await waitFor(() => expect(screen.queryByText('*.psd')).toBeNull())
  expect(fake.invoke).toHaveBeenCalledWith('git:lfsUntrack', 'repo', '*.psd')
})
it('updates submodules with progress scoped to the operation and cleans up', async () => {
  let complete!: () => void
  const fake = bridge()
  const normal = fake.invoke.getMockImplementation()!
  fake.invoke.mockImplementation((channel, ...args) => {
    if (channel === 'git:updateSubmodules')
      return new Promise((resolve) => {
        complete = () => resolve({ ok: true, value: undefined })
      })
    return normal(channel, ...args)
  })
  render(<RepositorySettingsDialog repository={repository} onClose={() => {}} />)
  fireEvent.click(screen.getByRole('tab', { name: '서브모듈' }))
  await screen.findByText('초기화 필요')
  fireEvent.click(screen.getByRole('button', { name: '모두 업데이트' }))
  const call = fake.invoke.mock.calls.find((args) => args[0] === 'git:updateSubmodules')!
  const { opId } = call[2] as { opId: string }
  act(() =>
    fake.emit('git:progress', {
      opId: 'other',
      progress: { kind: 'generic', title: '', value: 0.9 },
    })
  )
  expect(screen.getByRole('progressbar').getAttribute('value')).toBeNull()
  act(() =>
    fake.emit('git:progress', { opId, progress: { kind: 'generic', title: '', value: 0.4 } })
  )
  expect(screen.getByRole('progressbar').getAttribute('value')).toBe('0.4')
  await act(async () => complete())
  expect(screen.queryByRole('progressbar')).toBeNull()
})
it('disables tracking if bundled LFS is unavailable and supports keyboard tabs', async () => {
  installFakeBridge((channel) => {
    if (channel === 'git:lfsStatus')
      return { available: false, installedInRepository: false, trackedPatterns: [] }
    return []
  })
  render(<RepositorySettingsDialog repository={repository} onClose={() => {}} />)
  const remote = screen.getByRole('tab', { name: '원격' })
  fireEvent.keyDown(remote, { key: 'ArrowRight' })
  await screen.findByText(/사용 불가/)
  expect((screen.getByRole('button', { name: '패턴 추가' }) as HTMLButtonElement).disabled).toBe(
    true
  )
  expect(document.activeElement).toBe(screen.getByRole('tab', { name: 'Git LFS' }))
})
it('shows typed operation errors with details inside the modal', async () => {
  const fake = bridge()
  render(<RepositorySettingsDialog repository={repository} onClose={() => {}} />)
  fireEvent.click(screen.getByRole('tab', { name: 'Git LFS' }))
  await screen.findByText('*.psd')
  fake.invoke.mockResolvedValueOnce({
    ok: false,
    error: { kind: 'invalid-argument', message: 'bad pattern', detail: 'invalid glob' },
  } as never)
  fireEvent.click(screen.getByRole('button', { name: '삭제 *.psd' }))
  await screen.findByRole('alert')
  expect(screen.getByText('자세히')).toBeTruthy()
  expect(screen.getByText(/invalid glob/)).toBeTruthy()
})
it('hints only for new files at least 100 MiB and tracks the chosen pattern', async () => {
  const fake = bridge()
  const files = [{ path: 'large.psd', size: 100 * 1024 * 1024, isNew: true }]
  const view = render(<LargeFileHint repoId="repo" files={[{ ...files[0], isNew: false }]} />)
  expect(screen.queryByRole('complementary')).toBeNull()
  view.rerender(<LargeFileHint repoId="repo" files={[{ ...files[0], size: files[0].size - 1 }]} />)
  expect(screen.queryByRole('complementary')).toBeNull()
  view.rerender(<LargeFileHint repoId="repo" files={files} />)
  fireEvent.click(screen.getByRole('button', { name: 'Git LFS로 추적' }))
  await waitFor(() => expect(fake.invoke).toHaveBeenCalledWith('git:lfsTrack', 'repo', 'large.psd'))
  await waitFor(() => expect(screen.queryByRole('complementary')).toBeNull())
})

it('dismisses matching wildcard candidates and keeps unmatched files', async () => {
  const fake = bridge()
  render(
    <LargeFileHint
      repoId="repo"
      files={[
        { path: 'assets/large.psd', size: 100 * 1024 * 1024, isNew: true },
        { path: 'large.zip', size: 100 * 1024 * 1024, isNew: true },
      ]}
    />
  )
  fireEvent.change(screen.getByLabelText('추적할 패턴'), { target: { value: '*.psd' } })
  fireEvent.click(screen.getByRole('button', { name: 'Git LFS로 추적' }))
  await waitFor(() => expect(fake.invoke).toHaveBeenCalledWith('git:lfsTrack', 'repo', '*.psd'))
  await waitFor(() => expect(screen.queryByText(/assets\/large.psd/)).toBeNull())
  expect(screen.getByText('large.zip')).toBeTruthy()
})
