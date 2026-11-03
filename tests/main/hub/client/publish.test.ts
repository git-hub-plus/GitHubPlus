import { createServer, type Server } from 'node:http'
import { mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { afterEach, expect, it, vi } from 'vitest'
import { repository, run, commit } from '../../git/helpers'
import { publishRepository } from '../../../../src/main/hub/client/publish'

const servers: Server[] = []
afterEach(async () => {
  await Promise.all(
    servers.splice(0).map(
      (server) =>
        new Promise<void>((resolve) => {
          server.closeAllConnections()
          server.close(() => resolve())
        })
    )
  )
})
async function fakeApi(bare: string) {
  const requests: unknown[] = []
  const server = createServer(async (request, response) => {
    let body = ''
    for await (const chunk of request) body += chunk
    requests.push(JSON.parse(body))
    response.setHeader('Content-Type', 'application/json')
    response.end(JSON.stringify({ name: 'team', url: bare }))
  })
  servers.push(server)
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  return { url: `http://127.0.0.1:${(server.address() as { port: number }).port}`, requests }
}
it.each([false, true])(
  'adds the correct remote, pushes the current branch and sets upstream (origin exists: %s)',
  async (hasOrigin) => {
    const root = await repository()
    const sha = await commit(root, 'first')
    const bare = join(root, 'target.git')
    await mkdir(bare)
    await run(bare, ['init', '--bare'])
    if (hasOrigin) await run(root, ['remote', 'add', 'origin', 'https://example.com/existing.git'])
    const api = await fakeApi(bare)
    const progress = vi.fn()
    expect(
      await publishRepository(
        root,
        { hubUrl: api.url, name: 'team', description: 'project' },
        progress
      )
    ).toBe(bare)
    const remote = hasOrigin ? 'hub' : 'origin'
    expect(await run(root, ['remote', 'get-url', remote])).toBe(bare)
    expect(await run(bare, ['rev-parse', 'refs/heads/main'])).toBe(sha)
    expect(await run(root, ['config', '--get', 'branch.main.remote'])).toBe(remote)
    expect(await run(root, ['config', '--get', 'branch.main.merge'])).toBe('refs/heads/main')
    expect(progress.mock.calls.at(-1)?.[0]).toMatchObject({ kind: 'push', value: 1 })
    expect(api.requests).toEqual([{ name: 'team', description: 'project' }])
  }
)
it('rejects an occupied hub remote before creating a server repository', async () => {
  const root = await repository()
  await commit(root, 'first')
  await run(root, ['remote', 'add', 'origin', 'https://example.com/a.git'])
  await run(root, ['remote', 'add', 'hub', 'https://example.com/b.git'])
  const api = await fakeApi('unused')
  await expect(publishRepository(root, { hubUrl: api.url, name: 'team' })).rejects.toMatchObject({
    kind: 'invalid-argument',
  })
  expect(api.requests).toEqual([])
})

it('retains the created remote after a failed push for a normal push retry', async () => {
  const root = await repository()
  await commit(root, 'first')
  const missing = join(root, 'missing.git')
  const api = await fakeApi(missing)
  await expect(publishRepository(root, { hubUrl: api.url, name: 'team' })).rejects.toMatchObject({
    kind: expect.any(String),
  })
  expect(await run(root, ['remote', 'get-url', 'origin'])).toBe(missing)
  expect(api.requests).toHaveLength(1)
})
