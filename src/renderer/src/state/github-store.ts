import { create } from 'zustand'
import type { GitHubAccount, GitHubRepository } from '@shared/ipc/integrations'
import { GhpError } from '@shared/errors'
import { invoke } from '../ipc'

interface GitHubState {
  account: GitHubAccount | null
  repositories: ReadonlyArray<GitHubRepository>
  setAccount(account: GitHubAccount | null): void
  refreshAccount(): Promise<void>
  loadRepositories(): Promise<void>
  signOut(): Promise<void>
}
let sessionVersion = 0
export const useGitHubStore = create<GitHubState>((set) => ({
  account: null,
  repositories: [],
  setAccount(account) {
    sessionVersion++
    set({ account, repositories: [] })
  },
  async refreshAccount() {
    const version = sessionVersion
    try {
      const account = await invoke('github:account')
      if (version === sessionVersion)
        set(account ? { account } : { account: null, repositories: [] })
    } catch (error) {
      if (
        version === sessionVersion &&
        error instanceof GhpError &&
        error.kind === 'authentication-failed'
      ) {
        sessionVersion++
        set({ account: null, repositories: [] })
      }
      throw error
    }
  },
  async loadRepositories() {
    const version = sessionVersion
    try {
      const repositories = await invoke('github:repositories')
      if (version === sessionVersion) set({ repositories })
    } catch (error) {
      if (
        version === sessionVersion &&
        error instanceof GhpError &&
        error.kind === 'authentication-failed'
      ) {
        sessionVersion++
        set({ account: null, repositories: [] })
      }
      throw error
    }
  },
  async signOut() {
    sessionVersion++
    await invoke('github:signOut')
    set({ account: null, repositories: [] })
  },
}))
