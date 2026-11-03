// @vitest-environment jsdom
import { act, render, screen } from '@testing-library/react'
import { beforeEach, expect, it } from 'vitest'
import { installFakeBridge } from '../helpers/fake-bridge'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { useChangesStore } from '../../../src/renderer/src/state/changes-store'
import { ChangesView } from '../../../src/renderer/src/components/changes/ChangesView'
import { AppFileStatusKind } from '../../../src/shared/models/status'

beforeEach(() => {
  installFakeBridge((channel) => {
    if (channel === 'git:workingDiff') return { kind: 'binary' }
    if (channel === 'git:getIdentity')
      return { name: 'A', email: 'a@example.com', source: 'global' }
    if (channel === 'git:stashList') return []
    return undefined
  })
  useAppStore.setState({ selectedRepositoryId: 'repo', repositories: [] })
  useRepoStore.setState({
    repoId: 'repo',
    loading: false,
    status: {
      currentBranch: 'main',
      ahead: 0,
      behind: 0,
      stashCount: 0,
      files: [{ path: 'a.txt', status: { kind: AppFileStatusKind.Modified } }],
    },
  })
})

it('fills the commit box from an undo-commit draft and consumes it', async () => {
  render(<ChangesView />)
  act(() =>
    useChangesStore
      .getState()
      .setMessageDraft('repo', { summary: 'Undone summary', description: 'Undone body' })
  )
  expect(await screen.findByDisplayValue('Undone summary')).toBeTruthy()
  expect(screen.getByDisplayValue('Undone body')).toBeTruthy()
  expect(useChangesStore.getState().messageDrafts.repo).toBeUndefined()
})

it('fills the commit box when the view mounts with a pending draft (history tab -> changes tab)', async () => {
  useChangesStore
    .getState()
    .setMessageDraft('repo', { summary: 'From history', description: 'Body' })
  render(<ChangesView />)
  expect(await screen.findByDisplayValue('From history')).toBeTruthy()
  expect(useChangesStore.getState().messageDrafts.repo).toBeUndefined()
})
