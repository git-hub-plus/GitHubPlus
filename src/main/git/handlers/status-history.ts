import { handle } from '../../ipc'
import { getRepository } from '../../store/repositories'
import { withGitErrors } from '../core'
import { discardFiles } from '../discard'
import { getCommitFiles, getCommits } from '../log'
import { getStatus } from '../status'

export function register(): void {
  handle('git:status', (_event, id) => withGitErrors(() => getStatus(getRepository(id).path)))
  handle('git:discard', (_event, id, paths) =>
    withGitErrors(() => discardFiles(getRepository(id).path, paths))
  )
  handle('git:log', (_event, id, query) =>
    withGitErrors(() => getCommits(getRepository(id).path, query))
  )
  handle('git:commitFiles', (_event, id, sha) =>
    withGitErrors(() => getCommitFiles(getRepository(id).path, sha))
  )
}
