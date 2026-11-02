import { create } from 'zustand'
import type { DiffSelectionData } from '@shared/models/diff'
import { selectAll } from '@shared/models/diff-selection'
import type { WorkingFile } from '@shared/models/status'

interface ChangesState {
  repositories: Record<string, { selections: Record<string, DiffSelectionData>; path?: string }>
  sync(repoId: string, files: ReadonlyArray<WorkingFile>): void
  selectPath(repoId: string, path: string): void
  setSelection(repoId: string, path: string, selection: DiffSelectionData): void
}

export const useChangesStore = create<ChangesState>((set) => ({
  repositories: {},
  sync: (repoId, files) =>
    set((state) => {
      const previous = state.repositories[repoId]
      const selections = Object.fromEntries(
        files.map(({ path }) => [path, previous?.selections[path] ?? selectAll()])
      )
      const path = files.some((file) => file.path === previous?.path)
        ? previous?.path
        : files[0]?.path
      return { repositories: { ...state.repositories, [repoId]: { selections, path } } }
    }),
  selectPath: (repoId, path) =>
    set((state) => ({
      repositories: {
        ...state.repositories,
        [repoId]: { selections: state.repositories[repoId]?.selections ?? {}, path },
      },
    })),
  setSelection: (repoId, path, selection) =>
    set((state) => {
      const previous = state.repositories[repoId]
      if (!previous || !Object.hasOwn(previous.selections, path)) return state
      return {
        repositories: {
          ...state.repositories,
          [repoId]: { ...previous, selections: { ...previous.selections, [path]: selection } },
        },
      }
    }),
}))
