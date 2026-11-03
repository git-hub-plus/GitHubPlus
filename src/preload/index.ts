import { contextBridge, ipcRenderer, webUtils } from 'electron'
import type { GhpApi } from '@shared/ipc'

// The renderer has no Node access; this typed bridge is its only way out.
const api: GhpApi = {
  invoke: (channel, ...args) => ipcRenderer.invoke(channel, ...args),
  on(event, listener) {
    const wrapped = (_: Electron.IpcRendererEvent, payload: unknown) =>
      listener(payload as Parameters<typeof listener>[0])
    ipcRenderer.on(event, wrapped)
    return () => ipcRenderer.removeListener(event, wrapped)
  },
  getPathForFile: (file) => {
    try {
      return webUtils.getPathForFile(file)
    } catch {
      return ''
    }
  },
}

contextBridge.exposeInMainWorld('ghp', api)
