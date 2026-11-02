import { exec } from 'dugite'

export interface RepositoryInspection {
  /** Absolute repository root as reported by git. */
  readonly root: string
  readonly remoteUrl?: string
}

/**
 * Minimal checks used by the repository list before the full git layer
 * (`src/main/git/core`) exists. Returns null when `path` is not inside a
 * repository.
 */
export async function inspectRepository(path: string): Promise<RepositoryInspection | null> {
  const top = await exec(['rev-parse', '--show-toplevel'], path).catch(() => null)
  if (!top || top.exitCode !== 0) {
    return null
  }
  const root = top.stdout.trim()
  const remote = await exec(['remote', 'get-url', 'origin'], root).catch(() => null)
  const remoteUrl = remote && remote.exitCode === 0 ? remote.stdout.trim() : undefined
  return { root, remoteUrl: remoteUrl || undefined }
}

export async function initRepository(path: string, initialBranch: string): Promise<void> {
  const result = await exec(['init', '-b', initialBranch], path)
  if (result.exitCode !== 0) {
    throw new Error(result.stderr.trim() || 'git init failed')
  }
}

export async function getGitVersion(): Promise<string | undefined> {
  const result = await exec(['--version'], process.cwd()).catch(() => null)
  return result?.stdout.trim().replace(/^git version /, '') || undefined
}
