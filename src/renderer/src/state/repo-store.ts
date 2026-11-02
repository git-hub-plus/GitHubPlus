import { create } from 'zustand'
import type { RepoStatus } from '@shared/models/status'
import { GhpError } from '@shared/errors'
import { invoke, subscribe } from '../ipc'
import { useAppStore } from './app-store'

interface RepoState {
  /** Repository the status belongs to. */
  readonly repoId?: string
  readonly status?: RepoStatus
  readonly loading: boolean
  readonly error?: GhpError
  /** Re-reads status for the selected repository. */
  refresh(): Promise<void>
}

/**
 * Status of the selected repository, shared by the changes view and toolbar.
 * Refreshes on selection change, on `git:repoChanged` and on window focus.
 */
export const useRepoStore = create<RepoState>((set, get) => ({
  loading: false,

  async refresh() {
    const repoId = useAppStore.getState().selectedRepositoryId
    if (!repoId) {
      set({ repoId: undefined, status: undefined, error: undefined, loading: false })
      return
    }
    set({ loading: true, ...(get().repoId !== repoId ? { repoId, status: undefined } : {}) })
    try {
      const status = await invoke('git:status', repoId)
      if (useAppStore.getState().selectedRepositoryId === repoId) {
        set({ repoId, status, error: undefined, loading: false })
      }
    } catch (error) {
      set({ loading: false, error: error instanceof GhpError ? error : undefined })
    }
  },
}))

let started = false

/** Wires refresh triggers once; call from the app root after init. */
export function startRepoStatusUpdates(): void {
  if (started) return
  started = true
  const refresh = () => void useRepoStore.getState().refresh()
  useAppStore.subscribe((state, previous) => {
    if (state.selectedRepositoryId !== previous.selectedRepositoryId) refresh()
  })
  subscribe('git:repoChanged', ({ repoId }) => {
    if (repoId === useAppStore.getState().selectedRepositoryId) refresh()
  })
  window.addEventListener('focus', refresh)
  refresh()
}
