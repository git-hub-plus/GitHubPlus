import type { GitErrorKind } from '../models/git'
import type { AppEvents, AppIpc } from './app'
import type { GitEvents, GitIpc } from './git'

export type * from './app'
export type * from './git'

/**
 * Every request/response channel. New domains (hub, github, ai, advanced git)
 * add their own file and extend these two interfaces here.
 */
export interface IpcContract extends AppIpc, GitIpc {}
export interface IpcEventMap extends AppEvents, GitEvents {}

export type IpcChannel = keyof IpcContract
export type IpcEventName = keyof IpcEventMap

/** Wire format: handlers never throw across IPC, they return a result. */
export type IpcResult<T> =
  { readonly ok: true; readonly value: T } | { readonly ok: false; readonly error: IpcErrorInfo }

export interface IpcErrorInfo {
  readonly kind: GitErrorKind | 'invalid-argument' | 'not-found' | 'internal'
  readonly message: string
  /** Raw git stderr or extra detail for the "details" disclosure. */
  readonly detail?: string
}

/**
 * The bridge preload exposes as `window.ghp`. `invoke` resolves to the raw
 * `IpcResult` because custom error data does not survive contextBridge; use the
 * renderer's `invoke()` helper (src/renderer/src/ipc.ts), which throws GhpError.
 */
export interface GhpApi {
  invoke<C extends IpcChannel>(
    channel: C,
    ...args: Parameters<IpcContract[C]>
  ): Promise<IpcResult<Awaited<ReturnType<IpcContract[C]>>>>
  on<E extends IpcEventName>(event: E, listener: (payload: IpcEventMap[E]) => void): () => void
}
