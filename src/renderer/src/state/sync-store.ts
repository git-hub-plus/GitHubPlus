import { create } from 'zustand'
import type { TranslationKey } from '@shared/i18n'
import { useHistoryStore } from './history-store'
import type { GitProgress } from '@shared/models/git'
import { GhpError } from '@shared/errors'
import { invoke, subscribe } from '../ipc'
import { useAppStore } from './app-store'
import { useRepoStore } from './repo-store'
import { showToast } from './toast-store'

export const useSyncStore = create<{
  active?: { opId: string; repoId: string; progress?: GitProgress }
  lastFetch: Record<string, number>
  notices: ReadonlyArray<{
    id: string
    message: TranslationKey
    params: Record<string, string | number>
  }>
  needsPull?: string
}>(() => ({ lastFetch: {}, notices: [] }))

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
    const result = await action(opId)
    await refreshHistory(repoId)
    return result
  } finally {
    stop()
    useSyncStore.setState({ active: undefined })
  }
}

export async function synchronize(command: 'fetch' | 'pull' | 'push' | 'publish'): Promise<void> {
  const repoId = useAppStore.getState().selectedRepositoryId
  if (!repoId || useSyncStore.getState().active) return
  const status = useRepoStore.getState().status
  const branch = status?.currentBranch ?? ''
  const remote = status?.upstream?.slice(0, status.upstream.indexOf('/')) || 'origin'
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
      lastFetch: { ...s.lastFetch, [repoId]: Date.now() },
    }))
    await useRepoStore.getState().refresh()
    notifyOperation(`repoActions.completed.${command}`, { remote, branch })
  } catch (error) {
    if (error instanceof GhpError && error.kind === 'push-needs-pull')
      useSyncStore.setState({ needsPull: repoId })
    showToast(error)
  }
}

/** Refresh refs and graph after mutations even when no filesystem event arrives. */
export async function refreshHistory(repoId: string): Promise<void> {
  if (useHistoryStore.getState().repoId === repoId) await useHistoryStore.getState().load(true)
}

export function dismissOperation(id: string): void {
  useSyncStore.setState((s) => ({ notices: s.notices.filter((notice) => notice.id !== id) }))
}

/** Parameterized success notices live here because shared toast files have another owner. */
export function notifyOperation(
  message: TranslationKey,
  params: Record<string, string | number>
): void {
  const id = crypto.randomUUID()
  useSyncStore.setState((s) => ({ notices: [...s.notices, { id, message, params }] }))
  setTimeout(() => dismissOperation(id), 3500)
}
