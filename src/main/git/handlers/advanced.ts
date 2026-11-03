import { handle, broadcast } from '../../ipc'
import { getRepository } from '../../store/repositories'
import { withGitErrors } from '../core'
import { merge } from '../merge'
import { resolveConflict, markResolved, continueOperation, abortOperation } from '../conflicts'
import { stashList, stashCreate, stashApply, stashDrop, stashFiles, stashDiff } from '../stash'
import { revert } from '../revert'
import { undoLastCommit } from '../reset'
import { getTags, createTag, deleteTag, pushTag } from '../tag'
import { cherryPick } from '../cherry-pick'
import { rebase } from '../rebase'
import { squash } from '../squash'
import { reorder } from '../reorder'
import type { ProgressCallback } from '../progress/from-process'

const progress =
  (opId: string): ProgressCallback =>
  (progress) =>
    broadcast('git:progress', { opId, progress })
const at = <T>(id: string, work: (path: string) => Promise<T>): Promise<T> =>
  withGitErrors(() => work(getRepository(id).path))

/** N4 only; identity and LFS/submodules belong to their existing registrars. */
export function register(): void {
  handle('git:merge', (_event, id, branch, opts) => at(id, (path) => merge(path, branch, opts)))
  handle('git:resolveConflict', (_event, id, file, choice) =>
    at(id, (path) => resolveConflict(path, file, choice))
  )
  handle('git:markResolved', (_event, id, files) => at(id, (path) => markResolved(path, files)))
  handle('git:continueOperation', (_event, id, opts) =>
    at(id, (path) => continueOperation(path, opts))
  )
  handle('git:abortOperation', (_event, id) => at(id, abortOperation))
  handle('git:stashList', (_event, id) => at(id, stashList))
  handle('git:stashCreate', (_event, id, opts) => at(id, (path) => stashCreate(path, opts)))
  handle('git:stashApply', (_event, id, name, opts) =>
    at(id, (path) => stashApply(path, name, opts))
  )
  handle('git:stashDrop', (_event, id, name) => at(id, (path) => stashDrop(path, name)))
  handle('git:stashFiles', (_event, id, name) => at(id, (path) => stashFiles(path, name)))
  handle('git:stashDiff', (_event, id, name, file) => at(id, (path) => stashDiff(path, name, file)))
  handle('git:revert', (_event, id, sha) => at(id, (path) => revert(path, sha)))
  handle('git:undoLastCommit', (_event, id) => at(id, undoLastCommit))
  handle('git:tags', (_event, id) => at(id, getTags))
  handle('git:createTag', (_event, id, input) => at(id, (path) => createTag(path, input)))
  handle('git:deleteTag', (_event, id, name, opts) => at(id, (path) => deleteTag(path, name, opts)))
  handle('git:pushTag', (_event, id, name, opts) =>
    at(id, (path) => pushTag(path, name, opts, progress(opts.opId)))
  )
  handle('git:cherryPick', (_event, id, shas) => at(id, (path) => cherryPick(path, shas)))
  handle('git:rebase', (_event, id, base, opts) =>
    at(id, (path) => rebase(path, base, opts?.opId !== undefined ? progress(opts.opId) : undefined))
  )
  handle('git:squash', (_event, id, input) => at(id, (path) => squash(path, input)))
  handle('git:reorder', (_event, id, input) => at(id, (path) => reorder(path, input)))
}
