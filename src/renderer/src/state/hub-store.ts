import { create } from 'zustand'
import type { DiscoveredHub, HubPushRecord, HubServerStatus } from '@shared/ipc/hub'
import { invoke, subscribe } from '../ipc'
import { showToast } from './toast-store'

type HubDialog = 'clone' | 'manual' | 'publish' | 'host'
interface HubState {
  hubs: ReadonlyArray<DiscoveredHub>
  status?: HubServerStatus
  pushes: ReadonlyArray<HubPushRecord>
  dialog?: HubDialog
  repoId?: string
  open(dialog: HubDialog, repoId?: string): void
  close(): void
}
export const useHubStore = create<HubState>((set) => ({
  hubs: [],
  pushes: [],
  open: (dialog, repoId) => set({ dialog, repoId }),
  close: () => set({ dialog: undefined, repoId: undefined }),
}))

/** Mount once with the sidebar; subscribe before loading so events cannot be missed. */
export function connectHubStore(): () => void {
  let active = true
  let discoveryEvent = false
  const off = [
    subscribe('hub:discoveredChanged', (hubs) => {
      discoveryEvent = true
      useHubStore.setState({ hubs })
    }),
    subscribe('hub:statusChanged', (status) => useHubStore.setState({ status })),
    subscribe('hub:pushReceived', (push) =>
      useHubStore.setState((state) => ({ pushes: [push, ...state.pushes].slice(0, 100) }))
    ),
  ]
  void invoke('hub:discovered')
    .then((hubs) => {
      if (active && !discoveryEvent) useHubStore.setState({ hubs: Array.isArray(hubs) ? hubs : [] })
    })
    .catch((error) => {
      if (active) showToast(error)
    })
  return () => {
    active = false
    off.forEach((unsubscribe) => unsubscribe())
  }
}
