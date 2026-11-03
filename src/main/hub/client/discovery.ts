import type { DiscoveredHub } from '@shared/ipc/hub'
import { HandlerError } from '@shared/errors'
import { readJson, writeJson } from '../../store/json-file'
import { HubApi, normalizeHubUrl } from './api'

/** Transport-independent discovery state, so packet parsing and expiry can be tested without sockets. */
export class HubDiscovery {
  private hubs = new Map<string, DiscoveredHub>()
  private writes: Promise<void> = Promise.resolve()
  constructor(
    private readonly file: string,
    private readonly changed: (hubs: DiscoveredHub[]) => void,
    private readonly api = new HubApi(),
    private readonly now = Date.now
  ) {}

  list(): DiscoveredHub[] {
    return [...this.hubs.values()].sort((a, b) => a.url.localeCompare(b.url))
  }
  async load(): Promise<void> {
    const stored: unknown = await readJson(this.file, [])
    if (Array.isArray(stored))
      for (const item of stored) {
        try {
          if (!item || typeof item.url !== 'string' || typeof item.name !== 'string') continue
          const url = normalizeHubUrl(item.url)
          this.hubs.set(url, {
            id: url,
            url,
            name: item.name,
            lastSeen: 0,
            online: false,
            manual: true,
          })
        } catch {
          /* Ignore malformed saved entries. */
        }
      }
    this.changed(this.list())
  }
  receive(packet: Buffer, address: string): void {
    try {
      if (packet.length > 4096) return
      const data = JSON.parse(packet.toString('utf8')) as Record<string, unknown>
      if (
        data.type !== 'ghp-hub' ||
        typeof data.name !== 'string' ||
        !data.name.trim() ||
        data.name.length > 200 ||
        typeof data.version !== 'string' ||
        !Number.isInteger(data.port) ||
        Number(data.port) < 1 ||
        Number(data.port) > 65535
      )
        return
      const url = normalizeHubUrl(
        `http://${address.includes(':') ? `[${address}]` : address}:${data.port}`
      )
      this.hubs.set(url, {
        id: url,
        url,
        name: data.name,
        lastSeen: this.now(),
        online: true,
        manual: this.hubs.get(url)?.manual ?? false,
      })
      this.changed(this.list())
    } catch {
      /* Unrelated LAN packets are not errors. */
    }
  }
  expire(): void {
    let changed = false
    for (const [id, hub] of this.hubs)
      if (hub.online && this.now() - hub.lastSeen >= 15000) {
        this.hubs.set(id, { ...hub, online: false })
        changed = true
      }
    if (changed) this.changed(this.list())
  }
  private save(): Promise<void> {
    const snapshot = this.list().filter((hub) => hub.manual)
    const next = this.writes.catch(() => undefined).then(() => writeJson(this.file, snapshot))
    this.writes = next
    return next
  }
  async addManual(input: string): Promise<DiscoveredHub> {
    const url = normalizeHubUrl(input)
    const info = await this.api.info(url)
    if (
      !info ||
      typeof info.name !== 'string' ||
      !info.name.trim() ||
      typeof info.version !== 'string'
    )
      throw new HandlerError('network', '허브 응답을 확인할 수 없습니다.')
    const hub = { id: url, url, name: info.name, lastSeen: this.now(), manual: true, online: true }
    this.hubs.set(url, hub)
    await this.save()
    this.changed(this.list())
    return hub
  }
  async removeManual(id: string): Promise<void> {
    if (!this.hubs.get(id)?.manual) return
    this.hubs.delete(id)
    await this.save()
    this.changed(this.list())
  }
  matches(input: string): boolean {
    try {
      const url = new URL(input)
      return this.hubs.has(url.origin)
    } catch {
      return false
    }
  }
}
