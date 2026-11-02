// @vitest-environment jsdom
import { vi } from 'vitest'
import type { GhpApi, IpcEventMap, IpcEventName } from '@shared/ipc'
import type { RepositoryInfo } from '@shared/models/app'
import type { RepoStatus } from '@shared/models/status'
import { useAppStore } from '../../../src/renderer/src/state/app-store'
import { useRepoStore } from '../../../src/renderer/src/state/repo-store'
import { useDialogStore } from '../../../src/renderer/src/state/dialog-store'
import { useSyncStore } from '../../../src/renderer/src/state/sync-store'
import { useToastStore } from '../../../src/renderer/src/state/toast-store'
import { setLanguage } from '@shared/i18n'

export const repository: RepositoryInfo = {
  id: 'repo',
  name: 'example',
  path: 'C:/repos/example',
  group: 'local',
  pinned: false,
  available: true,
  addedAt: 0,
}
export const status: RepoStatus = {
  currentBranch: 'main',
  upstream: 'origin/main',
  ahead: 0,
  behind: 0,
  files: [],
  stashCount: 0,
}
export function setup() {
  setLanguage('ko')
  useAppStore.setState({
    ready: true,
    settings: { language: 'ko', theme: 'system', defaultRepositoryDirectory: 'C:/repos' },
    repositories: [repository],
    selectedRepositoryId: repository.id,
  })
  useRepoStore.setState({ repoId: repository.id, status, loading: false })
  useSyncStore.setState({ active: undefined, needsPull: undefined, lastFetch: {} })
  useToastStore.setState({ toasts: [] })
  useDialogStore.getState().close()
  Object.defineProperty(HTMLDialogElement.prototype, 'showModal', {
    configurable: true,
    value() {
      this.setAttribute('open', '')
    },
  })
  Object.defineProperty(HTMLDialogElement.prototype, 'close', {
    configurable: true,
    value() {
      this.removeAttribute('open')
    },
  })
  const listeners = new Map<string, Set<(payload: never) => void>>()
  const invoke = vi.fn(async (channel: string, ..._args: unknown[]) => {
    const values: Record<string, unknown> = {
      'git:status': status,
      'repos:list': [repository],
      'repos:open': repository,
      'repos:add': repository,
      'repos:create': repository,
      'git:clone': { ...repository, id: 'clone' },
      'settings:get': useAppStore.getState().settings,
      'git:branches': [],
      'app:getInfo': { name: 'GitHub+', version: '0.1.0', gitVersion: '2.50' },
    }
    return { ok: true, value: values[channel] }
  })
  const on = vi.fn((event: string, listener: (payload: never) => void) => {
    const group = listeners.get(event) ?? new Set()
    group.add(listener)
    listeners.set(event, group)
    return () => group.delete(listener)
  })
  Object.defineProperty(window, 'ghp', {
    configurable: true,
    value: { invoke, on } as unknown as GhpApi,
  })
  function emit<E extends IpcEventName>(event: E, payload: IpcEventMap[E]) {
    listeners.get(event)?.forEach((listener) => listener(payload as never))
  }
  return { invoke, on, emit }
}
