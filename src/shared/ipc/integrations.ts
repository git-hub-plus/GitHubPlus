import type { DiffSelectionData } from '../models/diff'
import type { RepositoryInfo } from '../models/app'

export interface GitHubAccount {
  readonly login: string
  readonly name?: string
  readonly avatarUrl?: string
}

export interface GitHubRepository {
  readonly fullName: string
  readonly cloneUrl: string
  readonly private: boolean
  readonly description?: string
  readonly updatedAt: number
}

export interface DeviceFlowStart {
  readonly userCode: string
  readonly verificationUri: string
  readonly expiresAt: number
  readonly intervalSeconds: number
}

/**
 * GitHub.com integration (N5). OAuth Device Flow with GitHub+'s own OAuth App
 * client id (no client secret). The token is stored with safeStorage and given
 * to git for github.com remotes through `registerGitAuthProvider` (core.ts).
 */
export interface GitHubIpc {
  'github:account': () => GitHubAccount | null
  'github:beginDeviceFlow': () => DeviceFlowStart
  /** Polls until the user approves; rejects on expiry, denial or cancel. */
  'github:completeDeviceFlow': () => GitHubAccount
  'github:cancelDeviceFlow': () => void
  'github:signOut': () => void
  'github:repositories': () => ReadonlyArray<GitHubRepository>
  /** Creates a GitHub repository, sets it as `origin` and pushes the current branch. */
  'github:publish': (
    repoId: string,
    input: { name: string; description?: string; private: boolean; opId: string }
  ) => RepositoryInfo
}

export type AiProvider = 'none' | 'anthropic' | 'openai-compatible'

export interface AiSettings {
  readonly provider: AiProvider
  readonly model?: string
  /** Only for openai-compatible (e.g. a local LLM server). */
  readonly baseUrl?: string
  readonly hasApiKey: boolean
}

export interface AiCommitFilesInput {
  readonly files: ReadonlyArray<{ readonly path: string; readonly selection: DiffSelectionData }>
}

/** AI commit messages (N5). The API key never leaves the main process. */
export interface AiIpc {
  'ai:getSettings': () => AiSettings
  /** `apiKey: null` clears the stored key; omitted keeps it. */
  'ai:updateSettings': (
    patch: Partial<Omit<AiSettings, 'hasApiKey'>> & { apiKey?: string | null }
  ) => AiSettings
  /** Exactly the text that would be sent, for the "what is sent" preview. */
  'ai:previewPayload': (repoId: string, input: AiCommitFilesInput) => string
  'ai:generateCommitMessage': (
    repoId: string,
    input: AiCommitFilesInput
  ) => { summary: string; description: string }
}
