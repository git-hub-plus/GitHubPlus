// @vitest-environment jsdom
import { render, screen } from '@testing-library/react'
import { expect, it } from 'vitest'
import { installFakeBridge } from '../helpers/fake-bridge'
import { NewLargeFilesHint } from '../../../src/renderer/src/components/changes/NewLargeFilesHint'
import { AppFileStatusKind } from '../../../src/shared/models/status'

it('offers LFS tracking only for new files of 100 MB or more', async () => {
  const bridge = installFakeBridge((channel, _repoId, paths) => {
    if (channel === 'files:sizes')
      return (paths as string[]).map((path) => (path === 'video.mp4' ? 150 * 1024 * 1024 : 10))
    if (channel === 'git:lfsStatus')
      return { available: true, installedInRepository: false, trackedPatterns: [] }
    return undefined
  })
  render(
    <NewLargeFilesHint
      repoId="repo"
      files={[
        { path: 'video.mp4', status: { kind: AppFileStatusKind.Untracked } },
        { path: 'small.txt', status: { kind: AppFileStatusKind.Untracked } },
        { path: 'old.bin', status: { kind: AppFileStatusKind.Modified } },
      ]}
    />
  )
  expect(await screen.findByText(/video\.mp4/)).toBeTruthy()
  expect(screen.queryByText(/small\.txt/)).toBeNull()
  expect(bridge.invoke).toHaveBeenCalledWith('files:sizes', 'repo', ['video.mp4', 'small.txt'])
})
