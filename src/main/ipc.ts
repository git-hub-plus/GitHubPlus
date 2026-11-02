import { BrowserWindow, ipcMain, type IpcMainInvokeEvent } from 'electron'
import type {
  IpcChannel,
  IpcContract,
  IpcErrorInfo,
  IpcEventMap,
  IpcEventName,
  IpcResult,
} from '@shared/ipc'
import { HandlerError } from '@shared/errors'
import { log } from './log'

type Handler<C extends IpcChannel> = (
  event: IpcMainInvokeEvent,
  ...args: Parameters<IpcContract[C]>
) => ReturnType<IpcContract[C]> | Promise<Awaited<ReturnType<IpcContract[C]>>>

const trustedWebContents = new Set<number>()

/** Only windows created by the app may call handlers. */
export function trustWebContents(id: number): void {
  trustedWebContents.add(id)
}

export function toErrorInfo(error: unknown): IpcErrorInfo {
  if (error instanceof HandlerError) {
    return { kind: error.kind, message: error.message, detail: error.detail }
  }
  const message = error instanceof Error ? error.message : String(error)
  return { kind: 'internal', message }
}

/** Registers a typed handler that always resolves to an `IpcResult`. */
export function handle<C extends IpcChannel>(channel: C, handler: Handler<C>): void {
  ipcMain.handle(channel, async (event, ...args): Promise<IpcResult<unknown>> => {
    if (!trustedWebContents.has(event.sender.id)) {
      log.warn(`Rejected IPC ${channel} from untrusted sender`)
      return { ok: false, error: { kind: 'internal', message: 'Untrusted sender' } }
    }
    try {
      const value = await handler(event, ...(args as Parameters<IpcContract[C]>))
      return { ok: true, value }
    } catch (error) {
      const info = toErrorInfo(error)
      if (info.kind === 'internal') {
        log.error(`IPC ${channel} failed`, error)
      }
      return { ok: false, error: info }
    }
  })
}

/** Sends a typed event to every app window. */
export function broadcast<E extends IpcEventName>(event: E, payload: IpcEventMap[E]): void {
  for (const window of BrowserWindow.getAllWindows()) {
    if (!window.isDestroyed()) {
      window.webContents.send(event, payload)
    }
  }
}
