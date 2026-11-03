import { create } from 'zustand'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { useRepoStore } from './repo-store'
import { showToast } from './toast-store'

export const useOperationStore = create<{ busy: Record<string, boolean> }>(() => ({ busy: {} }))
/** Serializes advanced mutations for each repository and refreshes after every attempt. */
export async function performOperation(
  repoId: string,
  action: () => Promise<unknown>
): Promise<boolean> {
  if (useOperationStore.getState().busy[repoId]) return false
  useOperationStore.setState((s) => ({ busy: { ...s.busy, [repoId]: true } }))
  try {
    const outcome = (await action()) as OperationOutcome | undefined
    showToast(
      outcome === 'nothing-to-do'
        ? 'conflicts.nothing'
        : outcome === 'conflicts'
          ? 'conflicts.conflicted'
          : 'conflicts.done',
      outcome === 'conflicts' ? 'error' : 'success'
    )
    return true
  } catch (error) {
    showToast(error)
    return false
  } finally {
    await useRepoStore.getState().refresh()
    useOperationStore.setState((s) => ({ busy: { ...s.busy, [repoId]: false } }))
  }
}
