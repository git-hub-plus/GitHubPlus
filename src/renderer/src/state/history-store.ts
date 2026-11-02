import { create } from 'zustand'
import type { Branch, Commit, CommittedFile } from '@shared/models/git'
import type { FileDiff } from '@shared/models/diff'
import { GhpError } from '@shared/errors'
import { invoke } from '../ipc'
import {
  calculateCommitGraph,
  emptyGraphState,
  type GraphRow,
  type GraphState,
} from '../lib/commit-graph'

interface HistoryState {
  repoId?: string
  commits: ReadonlyArray<Commit>
  rows: ReadonlyArray<GraphRow>
  graph: GraphState
  branches: ReadonlyArray<Branch>
  selectedSha?: string
  files: ReadonlyArray<CommittedFile>
  path?: string
  diff?: FileDiff
  all: boolean
  search: string
  loading: boolean
  detailLoading: boolean
  diffLoading: boolean
  hasMore: boolean
  error?: GhpError
  generation: number
  detailVersion: number
  diffVersion: number
  reset(repoId?: string): void
  load(refresh?: boolean): Promise<void>
  setAll(all: boolean): void
  setSearch(search: string): void
  select(sha: string): Promise<void>
  selectFile(path: string): Promise<void>
}
const asError = (error: unknown) =>
  error instanceof GhpError ? error : new GhpError({ kind: 'internal', message: String(error) })

export const useHistoryStore = create<HistoryState>((set, get) => ({
  commits: [],
  rows: [],
  graph: emptyGraphState(),
  branches: [],
  files: [],
  all: true,
  search: '',
  loading: false,
  detailLoading: false,
  diffLoading: false,
  hasMore: true,
  generation: 0,
  detailVersion: 0,
  diffVersion: 0,
  reset(repoId) {
    set({
      repoId,
      commits: [],
      rows: [],
      graph: emptyGraphState(),
      branches: [],
      files: [],
      selectedSha: undefined,
      path: undefined,
      diff: undefined,
      error: undefined,
      all: true,
      search: '',
      loading: false,
      detailLoading: false,
      diffLoading: false,
      hasMore: true,
      generation: get().generation + 1,
      detailVersion: get().detailVersion + 1,
      diffVersion: get().diffVersion + 1,
    })
  },
  async load(refresh = false) {
    const before = get()
    if (!before.repoId || (!refresh && (before.loading || !before.hasMore))) return
    const { repoId, all } = before
    const generation = before.generation + 1
    set({ loading: true, error: undefined, generation })
    try {
      const [page, branches] = await Promise.all([
        invoke('git:log', repoId, { all, limit: 200, skip: refresh ? 0 : before.commits.length }),
        invoke('git:branches', repoId),
      ])
      if (get().generation !== generation) return
      const graph = calculateCommitGraph(page, refresh ? emptyGraphState() : before.graph)
      const commits = refresh ? page : [...before.commits, ...page]
      set({
        commits,
        rows: refresh ? graph.rows : [...before.rows, ...graph.rows],
        graph: graph.state,
        branches,
        loading: false,
        hasMore: page.length === 200,
      })
      const selected = get().selectedSha
      if (!selected || !commits.some((commit) => commit.sha === selected)) {
        if (commits[0]) await get().select(commits[0].sha)
        else
          set({
            selectedSha: undefined,
            files: [],
            path: undefined,
            diff: undefined,
            detailVersion: get().detailVersion + 1,
            diffVersion: get().diffVersion + 1,
            detailLoading: false,
            diffLoading: false,
          })
      } else if (refresh) await get().select(selected)
    } catch (error) {
      if (get().generation === generation) set({ loading: false, error: asError(error) })
    }
  },
  setAll(all) {
    if (get().all === all) return
    const repoId = get().repoId
    get().reset(repoId)
    set({ all })
    void get().load()
  },
  setSearch: (search) => set({ search }),
  async select(sha) {
    const repoId = get().repoId
    if (!repoId) return
    const detailVersion = get().detailVersion + 1
    set({
      selectedSha: sha,
      files: [],
      path: undefined,
      diff: undefined,
      error: undefined,
      detailLoading: true,
      diffLoading: false,
      detailVersion,
      diffVersion: get().diffVersion + 1,
    })
    try {
      const files = await invoke('git:commitFiles', repoId, sha)
      if (get().detailVersion !== detailVersion) return
      set({ files, detailLoading: false })
      if (files[0]) await get().selectFile(files[0].path)
    } catch (error) {
      if (get().detailVersion === detailVersion)
        set({ detailLoading: false, error: asError(error) })
    }
  },
  async selectFile(path) {
    const { repoId, selectedSha } = get()
    if (!repoId || !selectedSha) return
    const diffVersion = get().diffVersion + 1
    set({ path, diff: undefined, diffLoading: true, error: undefined, diffVersion })
    try {
      const diff = await invoke('git:commitDiff', repoId, selectedSha, path)
      if (get().diffVersion === diffVersion) set({ diff, diffLoading: false })
    } catch (error) {
      if (get().diffVersion === diffVersion) set({ diffLoading: false, error: asError(error) })
    }
  },
}))
