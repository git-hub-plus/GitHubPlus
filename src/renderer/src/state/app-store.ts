import { create } from 'zustand'
import type { AppSettings, RepositoryInfo } from '@shared/models/app'
import { setLanguage } from '@shared/i18n'
import { invoke, subscribe } from '../ipc'

export type WorkspaceTab = 'changes' | 'history'

interface AppState {
  readonly ready: boolean
  readonly settings: AppSettings
  readonly repositories: ReadonlyArray<RepositoryInfo>
  readonly selectedRepositoryId?: string
  readonly tab: WorkspaceTab
  readonly preferencesOpen: boolean

  init(): Promise<void>
  updateSettings(patch: Partial<AppSettings>): Promise<void>
  selectRepository(id: string): Promise<void>
  setTab(tab: WorkspaceTab): void
  setPreferencesOpen(open: boolean): void
}

const lastRepositoryKey = 'ghp.lastRepositoryId'

/** App-level state: settings, repository list and selection, current tab. */
export const useAppStore = create<AppState>((set, get) => ({
  ready: false,
  settings: { language: 'ko', theme: 'system' },
  repositories: [],
  tab: 'changes',
  preferencesOpen: false,

  async init() {
    const [settings, repositories] = await Promise.all([
      invoke('settings:get'),
      invoke('repos:list'),
    ])
    setLanguage(settings.language)
    subscribe('settings:changed', (next) => {
      setLanguage(next.language)
      set({ settings: next })
    })
    subscribe('repos:changed', (list) => set({ repositories: list }))
    const last = localStorage.getItem(lastRepositoryKey) ?? undefined
    set({
      ready: true,
      settings,
      repositories,
      selectedRepositoryId: repositories.some((r) => r.id === last) ? last : repositories[0]?.id,
    })
  },

  async updateSettings(patch) {
    const settings = await invoke('settings:update', patch)
    setLanguage(settings.language)
    set({ settings })
  },

  async selectRepository(id) {
    if (get().selectedRepositoryId === id) {
      return
    }
    localStorage.setItem(lastRepositoryKey, id)
    set({ selectedRepositoryId: id })
    await invoke('repos:open', id)
  },

  setTab: (tab) => set({ tab }),
  setPreferencesOpen: (open) => set({ preferencesOpen: open }),
}))

export function useSelectedRepository(): RepositoryInfo | undefined {
  return useAppStore((s) => s.repositories.find((r) => r.id === s.selectedRepositoryId))
}
