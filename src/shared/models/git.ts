import type { AppFileStatus } from './status'

export interface CommitIdentity {
  readonly name: string
  readonly email: string
  /** Milliseconds since epoch. */
  readonly date: number
  /** Timezone offset in minutes, as recorded by git. */
  readonly tzOffset: number
}

export interface Commit {
  readonly sha: string
  readonly shortSha: string
  readonly summary: string
  readonly body: string
  readonly author: CommitIdentity
  readonly committer: CommitIdentity
  readonly parentShas: ReadonlyArray<string>
  readonly tags: ReadonlyArray<string>
}

/** A file changed by a commit. */
export interface CommittedFile {
  readonly path: string
  readonly status: AppFileStatus
}

export interface Branch {
  /** Full short name, e.g. `main` or `origin/main`. */
  readonly name: string
  readonly type: 'local' | 'remote'
  /** Remote name for remote branches, e.g. `origin`. */
  readonly remoteName?: string
  /** Upstream branch name for local branches, e.g. `origin/main`. */
  readonly upstream?: string
  readonly tipSha: string
  readonly tipDate?: number
  readonly isCurrent: boolean
}

export interface Remote {
  readonly name: string
  readonly url: string
}

export interface StashEntry {
  /** e.g. `stash@{0}` */
  readonly name: string
  readonly sha: string
  readonly branchName: string
  readonly message: string
  readonly createdAt: number
}

export interface Tag {
  readonly name: string
  readonly targetSha: string
}

export interface GitProgress {
  readonly kind: 'clone' | 'fetch' | 'pull' | 'push' | 'checkout' | 'generic'
  readonly title: string
  /** 0..1 */
  readonly value: number
  readonly description?: string
}

/** Classification of git failures the UI reacts to specifically. */
export type GitErrorKind =
  | 'not-a-repository'
  | 'authentication-failed'
  | 'push-rejected'
  | 'push-needs-pull'
  | 'merge-conflicts'
  | 'local-changes-overwritten'
  | 'branch-exists'
  | 'no-upstream'
  | 'network'
  | 'hub-history-protected'
  | 'unknown'
