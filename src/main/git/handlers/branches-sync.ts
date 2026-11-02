import { handle, broadcast } from '../../ipc'
import { addRepository, getRepository } from '../../store/repositories'
import { withGitErrors } from '../core'
import { getBranches } from '../for-each-ref'
import { createBranch, renameBranch, deleteBranch } from '../branch'
import { checkoutBranch } from '../checkout'
import { getRemotes } from '../remote'
import { fetch } from '../fetch'
import { pull } from '../pull'
import { push } from '../push'
import { clone } from '../clone'
import type { ProgressCallback } from '../progress/from-process'

function progress(opId: string): ProgressCallback {
  return (progress) => broadcast('git:progress', { opId, progress })
}

export function register(): void {
  handle('git:branches', (_event, id) => withGitErrors(() => getBranches(getRepository(id).path)))
  handle('git:createBranch', (_event, id, input) =>
    withGitErrors(() => createBranch(getRepository(id).path, input))
  )
  handle('git:checkout', (_event, id, branch, opts) =>
    withGitErrors(() =>
      checkoutBranch(
        getRepository(id).path,
        branch,
        opts?.opId !== undefined ? progress(opts.opId) : undefined
      )
    )
  )
  handle('git:renameBranch', (_event, id, oldName, newName) =>
    withGitErrors(() => renameBranch(getRepository(id).path, oldName, newName))
  )
  handle('git:deleteBranch', (_event, id, name, opts) =>
    withGitErrors(() => deleteBranch(getRepository(id).path, name, opts))
  )
  handle('git:remotes', (_event, id) => withGitErrors(() => getRemotes(getRepository(id).path)))
  handle('git:fetch', (_event, id, opts) =>
    withGitErrors(() => fetch(getRepository(id).path, opts.remote, progress(opts.opId)))
  )
  handle('git:pull', (_event, id, opts) =>
    withGitErrors(() => pull(getRepository(id).path, opts.remote, progress(opts.opId)))
  )
  handle('git:push', (_event, id, opts) =>
    withGitErrors(() => push(getRepository(id).path, opts, progress(opts.opId)))
  )
  handle('git:clone', (_event, input) =>
    withGitErrors(async () => {
      await clone(input, progress(input.opId))
      return addRepository(input.path)
    })
  )
}
