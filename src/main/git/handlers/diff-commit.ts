import { HandlerError } from '@shared/errors'
import { handle } from '../../ipc'
import { getRepository } from '../../store/repositories'
import { discardLines } from '../apply'
import { createCommit, withRepositoryOperation } from '../commit'
import { withGitErrors } from '../core'
import { getCommitDiff, getCommittedFile, getWorkingDiff } from '../diff'
import { getStatus } from '../status'

async function workingFile(repoPath: string, path: string) {
  const file = (await getStatus(repoPath)).files.find((f) => f.path === path)
  if (!file) throw new HandlerError('not-found', `Changed file not found: ${path}`)
  return file
}

export function register(): void {
  handle('git:workingDiff', (_event, id, path) =>
    withGitErrors(async () => {
      const repo = getRepository(id).path
      return getWorkingDiff(repo, await workingFile(repo, path))
    })
  )
  handle('git:commitDiff', (_event, id, sha, path) =>
    withGitErrors(async () => {
      const repo = getRepository(id).path
      return getCommitDiff(repo, sha, await getCommittedFile(repo, sha, path))
    })
  )
  handle('git:commit', (_event, id, input) =>
    withGitErrors(async () => {
      const repo = getRepository(id).path
      return withRepositoryOperation(repo, async () =>
        createCommit(repo, input, (await getStatus(repo)).files)
      )
    })
  )
  handle('git:discardLines', (_event, id, path, selection) =>
    withGitErrors(async () => {
      const repo = getRepository(id).path
      return withRepositoryOperation(repo, async () =>
        discardLines(repo, await workingFile(repo, path), selection)
      )
    })
  )
}
