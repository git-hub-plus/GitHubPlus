import { create } from 'zustand'

export type DialogKind = 'add' | 'create' | 'clone' | 'branch' | 'about'
export const useDialogStore = create<{
  kind?: DialogKind
  directory?: string
  open(kind: DialogKind, directory?: string): void
  close(): void
}>((set) => ({
  open: (kind, directory) => set({ kind, directory }),
  close: () => set({ kind: undefined, directory: undefined }),
}))
