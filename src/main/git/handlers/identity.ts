import { handle } from '../../ipc'
import { getRepository } from '../../store/repositories'
import { withGitErrors } from '../core'
import { getIdentity, setIdentity } from '../identity'

export function register(): void {
  handle('git:getIdentity', (_event, id) =>
    withGitErrors(() => getIdentity(getRepository(id).path))
  )
  handle('git:setIdentity', (_event, id, input) =>
    withGitErrors(() => setIdentity(getRepository(id).path, input))
  )
}
