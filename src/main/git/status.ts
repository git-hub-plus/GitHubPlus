import type { RepoStatus } from '@shared/models/status'

/**
 * Working directory status, ahead/behind and in-progress operation.
 * Owner: worker G2 (ports app/src/lib/git/status.ts + status-parser.ts).
 */
export async function getStatus(_repoPath: string): Promise<RepoStatus> {
  throw new Error('getStatus is not implemented yet (N1/G2)')
}
