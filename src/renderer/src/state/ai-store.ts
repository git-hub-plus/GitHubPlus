import { create } from 'zustand'
import type { AiSettings } from '@shared/ipc/integrations'
import { invoke } from '../ipc'

interface AiState {
  settings?: AiSettings
  load(): Promise<void>
  update(patch: Parameters<typeof invoke<'ai:updateSettings'>>[1]): Promise<void>
}

export const useAiStore = create<AiState>((set) => ({
  settings: undefined,
  load: async () => {
    set({ settings: await invoke('ai:getSettings') })
  },
  update: async (patch) => {
    set({ settings: await invoke('ai:updateSettings', patch) })
  },
}))
