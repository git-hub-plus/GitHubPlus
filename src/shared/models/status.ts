// File status types are ported from GitHub Desktop (MIT) `app/src/models/status.ts`.
// They are plain data so they can cross the IPC boundary unchanged.

/** Raw status codes reported by `git status --porcelain=v2`. */
export enum GitStatusEntry {
  Modified = 'M',
  Added = 'A',
  Deleted = 'D',
  Renamed = 'R',
  Copied = 'C',
  Unchanged = '.',
  Untracked = '?',
  Ignored = '!',
  UpdatedButUnmerged = 'U',
}

export enum AppFileStatusKind {
  New = 'New',
  Modified = 'Modified',
  Deleted = 'Deleted',
  Copied = 'Copied',
  Renamed = 'Renamed',
  Conflicted = 'Conflicted',
  Untracked = 'Untracked',
}

export enum UnmergedEntrySummary {
  AddedByUs = 'added-by-us',
  DeletedByUs = 'deleted-by-us',
  AddedByThem = 'added-by-them',
  DeletedByThem = 'deleted-by-them',
  BothDeleted = 'both-deleted',
  BothAdded = 'both-added',
  BothModified = 'both-modified',
}

export interface SubmoduleStatus {
  readonly commitChanged: boolean
  readonly modifiedChanges: boolean
  readonly untrackedChanges: boolean
}

export interface PlainFileStatus {
  readonly kind: AppFileStatusKind.New | AppFileStatusKind.Modified | AppFileStatusKind.Deleted
  readonly submoduleStatus?: SubmoduleStatus
}

export interface CopiedOrRenamedFileStatus {
  readonly kind: AppFileStatusKind.Copied | AppFileStatusKind.Renamed
  readonly oldPath: string
  readonly renameIncludesModifications: boolean
  readonly submoduleStatus?: SubmoduleStatus
}

export interface ConflictedFileStatus {
  readonly kind: AppFileStatusKind.Conflicted
  readonly action: UnmergedEntrySummary
  /**
   * Number of remaining conflict markers for text conflicts. Undefined for
   * conflicts that must be resolved by picking a side (binary, deleted, ...).
   */
  readonly conflictMarkerCount?: number
  readonly submoduleStatus?: SubmoduleStatus
}

export interface UntrackedFileStatus {
  readonly kind: AppFileStatusKind.Untracked
  readonly submoduleStatus?: SubmoduleStatus
}

export type AppFileStatus =
  PlainFileStatus | CopiedOrRenamedFileStatus | ConflictedFileStatus | UntrackedFileStatus

/** A changed file in the working directory. */
export interface WorkingFile {
  /** Path relative to the repository root, using forward slashes. */
  readonly path: string
  readonly status: AppFileStatus
}

/** An in-progress multi-step operation that left the repository mid-way. */
export type InProgressOperation =
  | { readonly kind: 'merge'; readonly theirBranch?: string }
  | {
      readonly kind: 'rebase'
      readonly targetBranch: string
      readonly baseBranch?: string
      readonly step: number
      readonly totalSteps: number
    }
  | { readonly kind: 'cherry-pick'; readonly step: number; readonly totalSteps: number }
  | { readonly kind: 'revert' }

export interface RepoStatus {
  /** Current branch name, or undefined when HEAD is detached or unborn. */
  readonly currentBranch?: string
  /** Commit SHA HEAD points to, undefined for an unborn branch. */
  readonly headSha?: string
  /** Upstream ref such as `origin/main`, when configured. */
  readonly upstream?: string
  readonly ahead: number
  readonly behind: number
  readonly files: ReadonlyArray<WorkingFile>
  readonly inProgress?: InProgressOperation
  readonly stashCount: number
}
