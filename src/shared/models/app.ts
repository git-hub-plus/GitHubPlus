import type { Language } from '../i18n'

export type ThemePreference = 'light' | 'dark' | 'system'

export interface AppSettings {
  readonly language: Language
  readonly theme: ThemePreference
  /** Default parent folder for clone / create dialogs. */
  readonly defaultRepositoryDirectory?: string
}

export interface AppInfo {
  readonly name: string
  readonly version: string
  readonly platform: string
  readonly gitVersion?: string
}

/** Where a repository's main remote lives; drives the sidebar group. */
export type RepositoryGroup = 'local' | 'hub' | 'github'

export interface RepositoryInfo {
  /** Stable id (hash of the absolute path). */
  readonly id: string
  readonly path: string
  readonly name: string
  readonly alias?: string
  readonly group: RepositoryGroup
  readonly remoteUrl?: string
  readonly pinned: boolean
  readonly addedAt: number
  readonly lastOpenedAt?: number
  /** False when the folder is gone or no longer a git repository. */
  readonly available: boolean
}

/** Commands sent from the native menu to the renderer. */
export type MenuCommand =
  | 'add-repository'
  | 'create-repository'
  | 'clone-repository'
  | 'open-preferences'
  | 'show-changes'
  | 'show-history'
  | 'command-palette'
  | 'fetch'
  | 'pull'
  | 'push'
  | 'new-branch'
  | 'about'
