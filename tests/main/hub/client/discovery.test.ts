import { mkdtemp, rm, readFile, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, expect, it, vi } from 'vitest'
import { HubDiscovery } from '../../../../src/main/hub/client/discovery'
import { HubApi } from '../../../../src/main/hub/client/api'

const roots: string[] = []
afterEach(async () => {
  vi.restoreAllMocks()
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })))
})
async function path() {
  const root = await mkdtemp(join(tmpdir(), 'ghp-hub-discovery-'))
  roots.push(root)
  return join(root, 'clients.json')
}
const packet = Buffer.from(
  JSON.stringify({ type: 'ghp-hub', name: 'office', port: 8765, version: '1' })
)
it('accepts UDP packets, ignores malformed packets, expires and revives hubs', async () => {
  let now = 100
  const changed = vi.fn()
  const discovery = new HubDiscovery(await path(), changed, new HubApi(), () => now)
  discovery.receive(packet, '192.168.0.2')
  expect(discovery.list()).toEqual([
    {
      id: 'http://192.168.0.2:8765',
      url: 'http://192.168.0.2:8765',
      name: 'office',
      manual: false,
      online: true,
      lastSeen: 100,
    },
  ])
  for (const text of ['broken', '{}', '{"type":"ghp-hub","port":-1}', '{"type":"other"}'])
    discovery.receive(Buffer.from(text), '192.168.0.2')
  expect(changed).toHaveBeenCalledTimes(1)
  now += 14999
  discovery.expire()
  expect(discovery.list()[0].online).toBe(true)
  now++
  discovery.expire()
  expect(discovery.list()[0].online).toBe(false)
  discovery.receive(packet, '192.168.0.2')
  expect(discovery.list()[0].online).toBe(true)
})
it('persists only manual hubs, retains offline entries, reloads and deletes them', async () => {
  const file = await path()
  vi.spyOn(HubApi.prototype, 'info').mockResolvedValue({ name: 'office', version: '1' })
  let now = 1
  const discovery = new HubDiscovery(file, vi.fn(), new HubApi(), () => now)
  discovery.receive(packet, '192.168.0.3')
  await discovery.addManual('192.168.0.2:8765')
  discovery.receive(packet, '192.168.0.2')
  expect(discovery.list().find((hub) => hub.manual)?.online).toBe(true)
  now += 15000
  discovery.expire()
  expect(discovery.list().find((hub) => hub.manual)?.online).toBe(false)
  expect(JSON.parse(await readFile(file, 'utf8'))).toHaveLength(1)
  const reloaded = new HubDiscovery(file, vi.fn())
  await reloaded.load()
  expect(reloaded.list()[0]).toMatchObject({ manual: true, online: false })
  expect(reloaded.matches('http://192.168.0.2:8765/team.git')).toBe(true)
  expect(reloaded.matches('http://192.168.0.2:8766/team.git')).toBe(false)
  expect(reloaded.matches('http://192.168.0.2.evil:8765/team.git')).toBe(false)
  await reloaded.removeManual(reloaded.list()[0].id)
  expect(reloaded.list()).toEqual([])
  expect(JSON.parse(await readFile(file, 'utf8'))).toEqual([])
})
it('does not add failed manual endpoints and ignores malformed saved entries', async () => {
  const file = await path()
  await writeFile(file, JSON.stringify([null, {}, { url: 'file:///bad', name: 'bad' }]))
  const discovery = new HubDiscovery(file, vi.fn())
  await discovery.load()
  expect(discovery.list()).toEqual([])
  vi.spyOn(HubApi.prototype, 'info').mockRejectedValue(new Error('offline'))
  await expect(discovery.addManual('localhost:1')).rejects.toThrow('offline')
  expect(discovery.list()).toEqual([])
})
it('merges one hub announced on several interfaces and keeps the best LAN address', async () => {
  const discovery = new HubDiscovery(await path(), vi.fn(), new HubApi(), () => 1)
  const withId = Buffer.from(
    JSON.stringify({
      type: 'ghp-hub',
      id: 'office-pc:8765',
      name: 'office',
      port: 8765,
      version: '1',
    })
  )
  for (const address of ['10.66.66.3', 'fd7a:115c:a1e0::3', '192.168.0.187', '10.253.187.1'])
    discovery.receive(withId, address)
  expect(discovery.list()).toHaveLength(1)
  expect(discovery.list()[0]).toMatchObject({
    id: 'hub:office-pc:8765',
    url: 'http://192.168.0.187:8765',
  })
  // Repositories cloned through any announced address still count as hub remotes.
  expect(discovery.matches('http://10.66.66.3:8765/team-api.git')).toBe(true)
  expect(discovery.matches('http://192.168.0.187:8765/team-api.git')).toBe(true)
  expect(discovery.matches('http://192.168.0.99:8765/x.git')).toBe(false)
})
