import type { AppInfo, AppSettings, MenuCommand, RepositoryInfo } from '../models/app'

export interface CreateRepositoryInput {
  readonly parentDirectory: string
  readonly name: string
  readonly initialBranch?: string
  readonly addReadme?: boolean
  readonly gitignoreTemplate?: string
}

/** App, settings and repository-list channels (request -> response). */
export interface AppIpc {
  'app:getInfo': () => AppInfo
  'settings:get': () => AppSettings
  'settings:update': (patch: Partial<AppSettings>) => AppSettings
  /** Opens a native folder picker; resolves to null when cancelled. */
  'dialog:pickDirectory': (options?: { title?: string; defaultPath?: string }) => string | null

  'repos:list': () => ReadonlyArray<RepositoryInfo>
  /** Adds an existing repository folder. Rejects with `not-a-repository`. */
  'repos:add': (path: string) => RepositoryInfo
  'repos:create': (input: CreateRepositoryInput) => RepositoryInfo
  'repos:remove': (id: string) => void
  'repos:update': (id: string, patch: { alias?: string | null; pinned?: boolean }) => RepositoryInfo
  /** Marks a repository as the active one (updates lastOpenedAt, starts watching). */
  'repos:open': (id: string) => RepositoryInfo
}

/** Events pushed from main to renderer. */
export interface AppEvents {
  'settings:changed': AppSettings
  'repos:changed': ReadonlyArray<RepositoryInfo>
  'menu:command': MenuCommand
}
