import type { RepositoryInfo } from '../models/app'
import type { DiffSelectionData, FileDiff } from '../models/diff'
import type { Branch, Commit, CommittedFile, GitProgress, Remote } from '../models/git'
import type { RepoStatus } from '../models/status'

export interface CommitInput {
  readonly summary: string
  readonly description?: string
  /** Files to include; files not listed are left untouched. */
  readonly files: ReadonlyArray<{ readonly path: string; readonly selection: DiffSelectionData }>
  readonly amend?: boolean
}

export interface LogQuery {
  /** Revision range or ref; defaults to HEAD. Use `--all` semantics with `all: true`. */
  readonly ref?: string
  readonly all?: boolean
  readonly skip?: number
  readonly limit: number
  /** Restrict to commits touching this path. */
  readonly path?: string
}

/** Long-running operations take an `opId` so progress events can be matched. */
export interface RemoteOperationOptions {
  readonly opId: string
  readonly remote?: string
}

export interface CloneInput {
  readonly opId: string
  readonly url: string
  /** Absolute destination folder (must not exist or be empty). */
  readonly path: string
  readonly branch?: string
}

/**
 * Core git channels (N1/N2 scope). Every call takes the repository id from
 * `RepositoryInfo.id`. Advanced operations (merge, stash, rebase, ...) live in
 * their own domain files added in later milestones.
 */
export interface GitIpc {
  'git:status': (repoId: string) => RepoStatus
  /** Diff of a working-directory file against HEAD (index ignored, like GitHub Desktop). */
  'git:workingDiff': (repoId: string, path: string) => FileDiff
  'git:commit': (repoId: string, input: CommitInput) => string
  /** Discards all changes in the given files. */
  'git:discard': (repoId: string, paths: ReadonlyArray<string>) => void
  /** Discards only the selected lines of one file. */
  'git:discardLines': (repoId: string, path: string, selection: DiffSelectionData) => void

  'git:log': (repoId: string, query: LogQuery) => ReadonlyArray<Commit>
  'git:commitFiles': (repoId: string, sha: string) => ReadonlyArray<CommittedFile>
  'git:commitDiff': (repoId: string, sha: string, path: string) => FileDiff

  'git:branches': (repoId: string) => ReadonlyArray<Branch>
  'git:createBranch': (
    repoId: string,
    input: { name: string; startPoint?: string; checkout?: boolean }
  ) => void
  'git:checkout': (repoId: string, branch: string, opts?: { opId?: string }) => void
  'git:renameBranch': (repoId: string, oldName: string, newName: string) => void
  'git:deleteBranch': (
    repoId: string,
    name: string,
    opts?: { force?: boolean; deleteRemote?: boolean }
  ) => void

  'git:remotes': (repoId: string) => ReadonlyArray<Remote>
  'git:fetch': (repoId: string, opts: RemoteOperationOptions) => void
  'git:pull': (repoId: string, opts: RemoteOperationOptions) => void
  'git:push': (
    repoId: string,
    opts: RemoteOperationOptions & { setUpstream?: boolean; branch?: string }
  ) => void
  /** Clones and registers the repository. */
  'git:clone': (input: CloneInput) => RepositoryInfo
}

export interface GitEvents {
  'git:progress': { readonly opId: string; readonly progress: GitProgress }
  /** The working directory or refs of a watched repository changed on disk. */
  'git:repoChanged': { readonly repoId: string }
}
