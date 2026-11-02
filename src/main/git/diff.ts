import type { FileDiff } from '@shared/models/diff'
import type { CommittedFile } from '@shared/models/git'
import type { WorkingFile } from '@shared/models/status'

/**
 * Diff of a working-directory file against HEAD (untracked files diff against
 * nothing). Line numbers must match what patch formatting expects.
 * Owner: worker G1 (ports app/src/lib/git/diff.ts + diff-parser.ts).
 */
export async function getWorkingDiff(_repoPath: string, _file: WorkingFile): Promise<FileDiff> {
  throw new Error('getWorkingDiff is not implemented yet (N1/G1)')
}

/** Diff of one file as changed by `sha` (against its first parent). Owner: G1. */
export async function getCommitDiff(
  _repoPath: string,
  _sha: string,
  _file: CommittedFile
): Promise<FileDiff> {
  throw new Error('getCommitDiff is not implemented yet (N1/G1)')
}
