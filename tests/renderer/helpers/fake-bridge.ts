import { vi } from 'vitest'
import type { GhpApi, IpcChannel, IpcEventMap, IpcEventName } from '@shared/ipc'

type Responder = (channel: IpcChannel, ...args: unknown[]) => unknown

/**
 * Installs a fake `window.ghp`. `respond` returns the value for a channel (or
 * throws `{ kind, message }` to simulate a failure). `emit` pushes events.
 */
export function installFakeBridge(respond: Responder) {
  const listeners = new Map<string, Set<(payload: unknown) => void>>()
  const invoke = vi.fn(async (channel: IpcChannel, ...args: unknown[]) => {
    try {
      return { ok: true, value: await respond(channel, ...args) }
    } catch (error) {
      const info = error as { kind?: string; message?: string }
      return {
        ok: false,
        error: { kind: info.kind ?? 'internal', message: info.message ?? String(error) },
      }
    }
  })
  const api: GhpApi = {
    invoke: invoke as unknown as GhpApi['invoke'],
    on: (event, listener) => {
      const set = listeners.get(event) ?? new Set()
      set.add(listener as (payload: unknown) => void)
      listeners.set(event, set)
      return () => set.delete(listener as (payload: unknown) => void)
    },
    getPathForFile: () => '',
  }
  Object.defineProperty(window, 'ghp', { value: api, configurable: true })
  return {
    invoke,
    emit<E extends IpcEventName>(event: E, payload: IpcEventMap[E]) {
      for (const listener of listeners.get(event) ?? []) listener(payload)
    },
  }
}
