import { create } from 'zustand'
import type { GitProgress } from '@shared/models/git'
import { GhpError } from '@shared/errors'
import { invoke, subscribe } from '../ipc'
import { useAppStore } from './app-store'
import { useRepoStore } from './repo-store'
import { showToast } from './toast-store'

export const useSyncStore = create<{
  active?: { opId: string; repoId: string; progress?: GitProgress }
  lastFetch: Record<string, number>
  needsPull?: string
}>(() => ({ lastFetch: {} }))

/** The subscription exists only for the lifetime of the operation. */
export async function runOperation<T>(
  repoId: string,
  action: (opId: string) => Promise<T>
): Promise<T> {
  if (useSyncStore.getState().active) throw new Error('Operation already running')
  const opId = crypto.randomUUID()
  useSyncStore.setState({ active: { repoId, opId } })
  const stop = subscribe('git:progress', (event) => {
    if (event.opId === opId)
      useSyncStore.setState({ active: { repoId, opId, progress: event.progress } })
  })
  try {
    return await action(opId)
  } finally {
    stop()
    useSyncStore.setState({ active: undefined })
  }
}

export async function synchronize(command: 'fetch' | 'pull' | 'push' | 'publish'): Promise<void> {
  const repoId = useAppStore.getState().selectedRepositoryId
  if (!repoId || useSyncStore.getState().active) return
  try {
    await runOperation(repoId, (opId) =>
      command === 'publish'
        ? invoke('git:push', repoId, {
            opId,
            setUpstream: true,
            branch: useRepoStore.getState().status?.currentBranch,
          })
        : invoke(`git:${command}`, repoId, { opId })
    )
    useSyncStore.setState((s) => ({
      needsPull: undefined,
      lastFetch:
        command === 'fetch' || command === 'pull'
          ? { ...s.lastFetch, [repoId]: Date.now() }
          : s.lastFetch,
    }))
    await useRepoStore.getState().refresh()
    showToast()
  } catch (error) {
    if (error instanceof GhpError && error.kind === 'push-needs-pull')
      useSyncStore.setState({ needsPull: repoId })
    showToast(error)
  }
}
