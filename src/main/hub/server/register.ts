import { app } from 'electron'
import { hostname } from 'node:os'
import { isAbsolute, join } from 'node:path'
import type { HubSettings } from '@shared/ipc/hub'
import { HandlerError } from '@shared/errors'
import { broadcast, handle } from '../../ipc'
import { log } from '../../log'
import { readJson, writeJson } from '../../store/json-file'
import { HubServer } from './server'

let host: HubServer | undefined
let ready: Promise<void> | undefined
let updating: Promise<unknown> = Promise.resolve()
const listeners = new Set<() => void>()

export function getHub(): HubServer | undefined {
  return host
}
export function onHubChanged(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

function validate(settings: HubSettings): void {
  if (
    !Number.isInteger(settings.port) ||
    settings.port < 1 ||
    settings.port > 65535 ||
    typeof settings.rootDirectory !== 'string' ||
    !isAbsolute(settings.rootDirectory) ||
    typeof settings.name !== 'string' ||
    !settings.name.trim() ||
    settings.name.length > 200 ||
    ['enabled', 'startWithWindows', 'keepRunningInTray'].some(
      (key) => typeof settings[key as keyof HubSettings] !== 'boolean'
    ) ||
    (settings.backupDirectory !== undefined &&
      (typeof settings.backupDirectory !== 'string' || !isAbsolute(settings.backupDirectory)))
  )
    throw new HandlerError('invalid-argument', 'Invalid hub settings')
}
function settingsPath(): string {
  return join(app.getPath('userData'), 'hub-settings.json')
}
async function initialize(): Promise<void> {
  const fallback: HubSettings = {
    enabled: false,
    port: 8765,
    rootDirectory: join(app.getPath('documents'), 'GitHubPlus Hub'),
    name: `${hostname()} 허브`,
    keepRunningInTray: true,
    startWithWindows: false,
  }
  let settings = { ...fallback, ...(await readJson<Partial<HubSettings>>(settingsPath(), {})) }
  try {
    validate(settings)
  } catch {
    settings = fallback
  }
  host = new HubServer(settings, app.getVersion(), {
    status: (status) => {
      broadcast('hub:statusChanged', status)
      for (const listener of listeners) listener()
    },
    push: (record) => broadcast('hub:pushReceived', record),
    error: (error) => log.error('Hub server error', error),
  })
  await writeJson(settingsPath(), settings)
  app.setLoginItemSettings({ openAtLogin: settings.startWithWindows })
  await host.refreshRepositoryCount()
  if (settings.enabled) await start()
}
async function start(): Promise<void> {
  await host!.start()
  if (host!.status().running)
    log.info('Hub started. Windows may ask to allow private-network access through the firewall.')
}
export async function updateHubSettings(patch: Partial<HubSettings>): Promise<HubSettings> {
  await ready
  const next = updating
    .catch(() => {})
    .then(async () => {
      const settings = { ...host!.settings, ...patch }
      validate(settings)
      await writeJson(settingsPath(), settings)
      await host!.stop()
      host!.settings = settings
      await host!.refreshRepositoryCount()
      app.setLoginItemSettings({ openAtLogin: settings.startWithWindows })
      if (settings.enabled) await start()
      for (const listener of listeners) listener()
      return settings
    })
  updating = next.then(
    () => {},
    () => {}
  )
  return next
}
export async function stopHub(): Promise<void> {
  await ready
  await updating.catch(() => {})
  await host?.stop()
}

export function register(): void {
  ready = initialize().catch((error: unknown) => {
    log.error('Hub initialization failed', error)
    throw error
  })
  void ready.catch(() => {})
  handle('hub:getSettings', async () => {
    await ready
    return { ...host!.settings }
  })
  handle('hub:updateSettings', (_event, patch) => updateHubSettings(patch))
  handle('hub:status', async () => {
    await ready
    return host!.status()
  })
  handle('hub:listLocalRepositories', async () => {
    await ready
    await updating
    return host!.list()
  })
  handle('hub:createLocalRepository', async (_event, name, description) => {
    await ready
    await updating
    return host!.create(name, description)
  })
  handle('hub:deleteLocalRepository', async (_event, name) => {
    await ready
    await updating
    await host!.delete(name)
  })
  handle('hub:pushLog', async (_event, query) => {
    await ready
    await updating
    return host!.pushLog(query)
  })
}
