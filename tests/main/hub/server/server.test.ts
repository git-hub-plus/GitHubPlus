import { afterEach, describe, expect, it, vi } from 'vitest'
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { gzipSync } from 'node:zlib'
import { createServer } from 'node:http'
import { exec } from 'dugite'
import { HubServer } from '../../../../src/main/hub/server/server'
import type { HubPushRecord } from '../../../../src/shared/ipc/hub'

vi.mock('../../../../src/main/log', () => ({
  log: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}))

const roots: string[] = []
const servers: HubServer[] = []
afterEach(async () => {
  await Promise.all(servers.splice(0).map((s) => s.stop()))
  await Promise.all(roots.splice(0).map((r) => rm(r, { recursive: true, force: true })))
})
async function git(cwd: string, args: string[], success = true): Promise<string> {
  const result = await exec(
    [
      '-c',
      'core.autocrlf=false',
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.com',
      ...args,
    ],
    cwd,
    { env: { GIT_TERMINAL_PROMPT: '0' } }
  )
  expect(result.exitCode, result.stderr).toBe(success ? 0 : 1)
  return success ? result.stdout.trim() : result.stderr
}
async function setup(): Promise<{
  root: string
  hub: HubServer
  url: string
  records: HubPushRecord[]
}> {
  const root = await mkdtemp(join(tmpdir(), 'ghp-hub-'))
  roots.push(root)
  const records: HubPushRecord[] = []
  const hub = new HubServer(
    {
      enabled: true,
      port: 0,
      name: 'Test Hub',
      rootDirectory: join(root, 'hub'),
      startWithWindows: false,
      keepRunningInTray: true,
    },
    '1.0-test',
    {
      status: vi.fn(),
      push: (r) => records.push(r),
      error: (error) => {
        throw error
      },
    },
    false
  )
  servers.push(hub)
  await hub.start()
  expect(hub.status().running, hub.status().error).toBe(true)
  return { root, hub, url: `http://127.0.0.1:${hub.status().port}`, records }
}

describe('hub HTTP integration', () => {
  it('uses the first published branch as HEAD and retains records after restart', async () => {
    const { root, hub, url } = await setup()
    await hub.create('custom')
    await git(root, ['clone', `${url}/custom.git`, 'custom-client'])
    const client = join(root, 'custom-client')
    await git(client, ['commit', '--allow-empty', '-m', 'published'])
    await git(client, ['branch', '-M', 'published-branch'])
    await git(client, ['push', 'origin', 'HEAD'])
    await git(root, ['clone', `${url}/custom.git`, 'fresh'])
    expect(await git(join(root, 'fresh'), ['symbolic-ref', '--short', 'HEAD'])).toBe(
      'published-branch'
    )
    expect(await (await fetch(`${url}/api/repos/custom/log`)).json()).toMatchObject([
      { summary: 'published' },
    ])
    for (const [key, value] of Object.entries({
      'receive.denyNonFastForwards': 'true',
      'receive.denyDeletes': 'true',
      'core.logAllRefUpdates': 'true',
      'gc.reflogExpire': 'never',
      'gc.reflogExpireUnreachable': 'never',
      'http.receivepack': 'true',
    })) {
      expect(await git(join(root, 'hub', 'custom.git'), ['config', '--get', key])).toBe(value)
    }
    await hub.stop()
    await hub.start()
    expect(await hub.pushLog({ limit: 10 })).toMatchObject([
      { repository: 'custom', ref: 'refs/heads/published-branch' },
    ])
    expect(hub.status().repositoryCount).toBe(1)
  })
  it('serves real clone/push/pull, protects history and exposes commit APIs and durable audit', async () => {
    const { root, hub, url, records } = await setup()
    expect(await (await fetch(`${url}/api/info`)).json()).toEqual({
      name: 'Test Hub',
      version: '1.0-test',
    })
    const create = (): Promise<Response> =>
      fetch(`${url}/api/repos`, {
        method: 'POST',
        body: JSON.stringify({ name: 'team', description: 'Team repo' }),
      })
    expect((await create()).status).toBe(201)
    expect((await create()).status).toBe(409)
    expect(await (await fetch(`${url}/api/repos`)).json()).toMatchObject([
      { name: 'team', description: 'Team repo' },
    ])
    expect(await (await fetch(`${url}/api/repos/team/log`)).json()).toEqual([])
    await git(root, ['clone', `${url}/team.git`, 'one'])
    const one = join(root, 'one')
    await writeFile(join(one, 'hello.txt'), 'hello\n')
    await git(one, ['add', '.'])
    await git(one, ['commit', '-m', 'first'])
    await git(one, ['branch', '-M', 'main'])
    const first = await git(one, ['rev-parse', 'HEAD'])
    await git(one, ['push', 'origin', 'main'])
    await git(root, ['clone', `${url}/team.git`, 'two'])
    await writeFile(join(one, 'hello.txt'), 'hello again\n')
    await git(one, ['commit', '-am', 'second'])
    const second = await git(one, ['rev-parse', 'HEAD'])
    await git(one, ['push', 'origin', 'main'])
    await git(join(root, 'two'), ['pull', '--ff-only'])
    expect(await readFile(join(root, 'two', 'hello.txt'), 'utf8')).toBe('hello again\n')
    const forced = await git(one, ['push', '--force', 'origin', `${first}:main`], false)
    expect(forced).toMatch(/non-fast-forward|denying/i)
    expect(await git(one, ['push', 'origin', '--delete', 'main'], false)).toMatch(/delet|declined/i)
    await git(one, ['tag', 'v1'])
    await git(one, ['push', 'origin', 'v1'])
    expect(await git(one, ['push', 'origin', '--delete', 'v1'], false)).toContain(
      'Hub history protection'
    )
    expect(await git(one, ['push', '--force', 'origin', `${first}:refs/tags/v1`], false)).toContain(
      'rewriting tags is forbidden'
    )
    expect(records.filter((r) => r.ref === 'refs/heads/main')).toMatchObject([
      { repository: 'team', oldSha: '0'.repeat(40), newSha: first, clientAddress: '127.0.0.1' },
      { repository: 'team', oldSha: first, newSha: second, clientAddress: '127.0.0.1' },
    ])
    expect(await hub.pushLog({ repository: 'team', limit: 100 })).toHaveLength(3)
    const log = await (await fetch(`${url}/api/repos/team/log?limit=1`)).json()
    expect(log).toMatchObject([{ sha: second, summary: 'second' }])
    expect(
      await (await fetch(`${url}/api/repos/team/commits/${first}/files`)).json()
    ).toMatchObject([{ path: 'hello.txt' }])
    expect(
      await (await fetch(`${url}/api/repos/team/commits/${first}/diff?path=hello.txt`)).json()
    ).toMatchObject({ kind: 'text', text: expect.stringContaining('+hello') })
    // Exercise the gzip request path using a valid upload-pack protocol request.
    const want = `want ${second}\n`
    const body = `${(Buffer.byteLength(want) + 4).toString(16).padStart(4, '0')}${want}00000009done\n`
    const response = await fetch(`${url}/team.git/git-upload-pack`, {
      method: 'POST',
      headers: { 'Content-Encoding': 'gzip' },
      body: new Uint8Array(gzipSync(body)),
    })
    expect(response.status).toBe(200)
    expect(Buffer.from(await response.arrayBuffer()).includes(Buffer.from('PACK'))).toBe(true)
    await hub.delete('team')
    expect(await hub.list()).toEqual([])
    expect((await readdir(join(root, 'hub', '.trash')))[0]).toMatch(/^team-.*\.git$/)
  }, 60000)

  it('rejects invalid input and reports bind conflicts', async () => {
    const { hub, url } = await setup()
    for (const name of ['../escape', 'a..b', 'CON', 'x/y', '']) {
      expect(
        (await fetch(`${url}/api/repos`, { method: 'POST', body: JSON.stringify({ name }) })).status
      ).toBe(400)
    }
    expect((await fetch(`${url}/api/repos`, { method: 'POST', body: 'null' })).status).toBe(400)
    await expect(hub.create('../escape')).rejects.toThrow('Invalid repository name')
    await hub.create('empty')
    expect((await fetch(`${url}/api/repos/empty/log?limit=-1`)).status).toBe(400)
    const occupied = createServer()
    await new Promise<void>((resolve) => occupied.listen(0, resolve))
    const address = occupied.address()
    const conflict = new HubServer(
      { ...hub.settings, port: typeof address === 'object' && address ? address.port : 0 },
      'test',
      { status: vi.fn(), push: vi.fn(), error: vi.fn() },
      false
    )
    servers.push(conflict)
    try {
      await conflict.start()
      expect(conflict.status()).toMatchObject({
        running: false,
        error: expect.stringContaining('EADDRINUSE'),
      })
    } finally {
      await new Promise<void>((resolve) => occupied.close(() => resolve()))
    }
  })
})
