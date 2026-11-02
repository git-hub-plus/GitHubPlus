import type { GhpApi } from '../shared/ipc'

declare global {
  interface Window {
    readonly ghp: GhpApi
  }
}

export {}
