import type { IpcChannel, IpcContract, IpcEventMap, IpcEventName } from '@shared/ipc'
import { GhpError } from '@shared/errors'

/** Calls a main-process handler; throws GhpError (with `kind`) on failure. */
export async function invoke<C extends IpcChannel>(
  channel: C,
  ...args: Parameters<IpcContract[C]>
): Promise<Awaited<ReturnType<IpcContract[C]>>> {
  const result = await window.ghp.invoke(channel, ...args)
  if (result.ok) {
    return result.value
  }
  throw new GhpError(result.error)
}

export function subscribe<E extends IpcEventName>(
  event: E,
  listener: (payload: IpcEventMap[E]) => void
): () => void {
  return window.ghp.on(event, listener)
}
