import type { FileDiff } from '../models/diff'
import type { CommittedFile, StashEntry, Tag } from '../models/git'

/** Result of operations that may stop on conflicts. */
export type OperationOutcome = 'success' | 'conflicts' | 'nothing-to-do'

export interface GitIdentity {
  readonly name?: string
  readonly email?: string
  /** Where the effective value comes from. */
  readonly source: 'repository' | 'global' | 'none'
}

export interface Submodule {
  readonly path: string
  readonly url?: string
  readonly sha?: string
  readonly status: 'up-to-date' | 'out-of-date' | 'uninitialized' | 'conflicted'
}

export interface LfsStatus {
  readonly available: boolean
  readonly installedInRepository: boolean
  /** Patterns from .gitattributes with `filter=lfs`. */
  readonly trackedPatterns: ReadonlyArray<string>
}

/**
 * Advanced git channels (N2 polish, N4, N5). Conflicts are reported through the
 * outcome plus `git:status` (`inProgress`, conflicted files), not as errors.
 */
export interface GitAdvancedIpc {
  // Identity (N2 polish)
  'git:getIdentity': (repoId: string) => GitIdentity
  'git:setIdentity': (
    repoId: string,
    input: { name: string; email: string; scope: 'repository' | 'global' }
  ) => GitIdentity

  // Merge & conflicts (N4)
  'git:merge': (repoId: string, branch: string, opts?: { squash?: boolean }) => OperationOutcome
  'git:resolveConflict': (repoId: string, path: string, choice: 'ours' | 'theirs') => void
  'git:markResolved': (repoId: string, paths: ReadonlyArray<string>) => void
  /** Finishes the in-progress merge/rebase/cherry-pick/revert. */
  'git:continueOperation': (repoId: string, opts?: { message?: string }) => OperationOutcome
  'git:abortOperation': (repoId: string) => void
  /** Message git prepared for the in-progress operation (MERGE_MSG etc.), comments removed. */
  'git:pendingOperationMessage': (repoId: string) => string

  // Stash (N4)
  'git:stashList': (repoId: string) => ReadonlyArray<StashEntry>
  'git:stashCreate': (
    repoId: string,
    opts?: { message?: string; includeUntracked?: boolean }
  ) => void
  'git:stashApply': (repoId: string, name: string, opts?: { pop?: boolean }) => OperationOutcome
  'git:stashDrop': (repoId: string, name: string) => void
  'git:stashFiles': (repoId: string, name: string) => ReadonlyArray<CommittedFile>
  'git:stashDiff': (repoId: string, name: string, path: string) => FileDiff

  // Undo, revert, tags (N4)
  'git:revert': (repoId: string, sha: string) => OperationOutcome
  /** Soft-resets HEAD~1 and returns the undone message for the commit box. */
  'git:undoLastCommit': (repoId: string) => { summary: string; description: string }
  'git:tags': (repoId: string) => ReadonlyArray<Tag>
  'git:createTag': (repoId: string, input: { name: string; sha: string; message?: string }) => void
  'git:deleteTag': (repoId: string, name: string, opts?: { remote?: string }) => void
  'git:pushTag': (repoId: string, name: string, opts: { opId: string; remote?: string }) => void

  // History editing (N4)
  'git:cherryPick': (repoId: string, shas: ReadonlyArray<string>) => OperationOutcome
  'git:rebase': (repoId: string, baseBranch: string, opts?: { opId?: string }) => OperationOutcome
  /** Squashes `shas` (oldest first) into one commit with `message`. */
  'git:squash': (
    repoId: string,
    input: { shas: ReadonlyArray<string>; message: string }
  ) => OperationOutcome
  /** Moves `shas` so they come right after `afterSha` (null = to the oldest position). */
  'git:reorder': (
    repoId: string,
    input: { shas: ReadonlyArray<string>; afterSha: string | null }
  ) => OperationOutcome

  /** Whether each commit is on the current branch and already on a remote (N6). */
  'git:commitPlacement': (
    repoId: string,
    shas: ReadonlyArray<string>
  ) => ReadonlyArray<{ sha: string; onCurrentBranch: boolean; pushed: boolean }>

  // LFS & submodules (N5)
  'git:submodules': (repoId: string) => ReadonlyArray<Submodule>
  'git:updateSubmodules': (repoId: string, opts: { opId: string }) => void
  'git:lfsStatus': (repoId: string) => LfsStatus
  'git:lfsTrack': (repoId: string, pattern: string) => void
  'git:lfsUntrack': (repoId: string, pattern: string) => void
}

/** Copies dropped files/folders into the working tree (N5 drag & drop). */
export interface FilesIpc {
  'files:copyIntoRepository': (
    repoId: string,
    input: { sources: ReadonlyArray<string>; targetDirectory: string }
  ) => { copied: ReadonlyArray<string>; skipped: ReadonlyArray<string> }
  /** Sizes in bytes of working-tree files (null when missing or not a regular file). */
  'files:sizes': (repoId: string, paths: ReadonlyArray<string>) => ReadonlyArray<number | null>
}
