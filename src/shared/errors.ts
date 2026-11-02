import type { IpcErrorInfo } from './ipc'

/** Error thrown in the renderer when an IPC call fails; keeps the error kind. */
export class GhpError extends Error {
  public readonly kind: IpcErrorInfo['kind']
  public readonly detail?: string

  public constructor(info: IpcErrorInfo) {
    super(info.message)
    this.name = 'GhpError'
    this.kind = info.kind
    this.detail = info.detail
  }
}

/** Error thrown inside main-process handlers to report a specific kind. */
export class HandlerError extends Error {
  public constructor(
    public readonly kind: IpcErrorInfo['kind'],
    message: string,
    public readonly detail?: string
  ) {
    super(message)
    this.name = 'HandlerError'
  }
}
