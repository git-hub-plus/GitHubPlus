import { broadcast, handle } from '../../ipc'
import { getRepository } from '../../store/repositories'
import { withGitErrors } from '../core'
import { getLfsStatus, trackLfsPattern, untrackLfsPattern } from '../lfs'
import { listSubmodules, updateSubmodules } from '../submodule'

export function register(): void {
  handle('git:lfsStatus', (_event, id) => withGitErrors(() => getLfsStatus(getRepository(id).path)))
  handle('git:lfsTrack', (_event, id, pattern) =>
    withGitErrors(() => trackLfsPattern(getRepository(id).path, pattern))
  )
  handle('git:lfsUntrack', (_event, id, pattern) =>
    withGitErrors(() => untrackLfsPattern(getRepository(id).path, pattern))
  )
  handle('git:submodules', (_event, id) =>
    withGitErrors(() => listSubmodules(getRepository(id).path))
  )
  handle('git:updateSubmodules', (_event, id, { opId }) =>
    withGitErrors(() =>
      updateSubmodules(getRepository(id).path, (progress) =>
        broadcast('git:progress', { opId, progress })
      )
    )
  )
}
