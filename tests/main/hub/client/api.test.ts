import { createServer, type Server, type RequestListener } from 'node:http'
import { afterEach, expect, it } from 'vitest'
import { HubApi, normalizeHubUrl } from '../../../../src/main/hub/client/api'

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
async function serve(handler: RequestListener): Promise<string> {
  const server = createServer(handler)
  servers.push(server)
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve))
  return `http://127.0.0.1:${(server.address() as { port: number }).port}`
}

it('normalizes bare addresses and rejects credentials, paths and non-HTTP schemes', () => {
  expect(normalizeHubUrl('192.168.0.10:8765/')).toBe('http://192.168.0.10:8765')
  for (const url of [
    'file:///tmp',
    'http://user:secret@localhost',
    'http://localhost/path',
    'http://localhost/?q=x',
  ])
    expect(() => normalizeHubUrl(url)).toThrow()
})
it('lists, creates and calls history endpoints with escaped names and query values', async () => {
  const requests: Array<{ path: string; method?: string; body: string }> = []
  const repo = { name: 'team', description: 'test', url: 'http://localhost/team.git' }
  const url = await serve(async (request, response) => {
    let body = ''
    for await (const part of request) body += part
    requests.push({ path: request.url!, method: request.method, body })
    response.setHeader('Content-Type', 'application/json')
    response.end(
      JSON.stringify(
        request.method === 'POST'
          ? repo
          : request.url === '/api/info'
            ? { name: 'office', version: '1' }
            : request.url?.includes('/diff?')
              ? { kind: 'binary' }
              : [repo]
      )
    )
  })
  const api = new HubApi()
  expect(await api.info(url)).toEqual({ name: 'office', version: '1' })
  expect(await api.list(url)).toEqual([repo])
  expect(await api.create(url, 'team', 'test')).toEqual(repo)
  expect(requests[2]).toEqual({
    path: '/api/repos',
    method: 'POST',
    body: JSON.stringify({ name: 'team', description: 'test' }),
  })
  await api.log(url, 'team space', { ref: 'feature/a&b', limit: 20, skip: 3 })
  await api.files(url, 'team', 'abc')
  expect(await api.diff(url, 'team', 'abc', 'a/b & c.txt')).toEqual({ kind: 'binary' })
  expect(requests[3].path).toBe('/api/repos/team%20space/log?limit=20&skip=3&ref=feature%2Fa%26b')
  expect(requests[4].path).toBe('/api/repos/team/commits/abc/files')
  expect(requests[5].path).toBe('/api/repos/team/commits/abc/diff?path=a%2Fb+%26+c.txt')
})
it('maps 409, 404, invalid JSON, HTTP failure and a timeout to typed errors', async () => {
  const url = await serve((request, response) => {
    if (request.url === '/timeout') return
    if (request.url === '/body-timeout') {
      response.writeHead(200, { 'Content-Type': 'application/json' })
      response.write('[')
      return
    }
    response.statusCode =
      request.url === '/conflict'
        ? 409
        : request.url === '/missing'
          ? 404
          : request.url === '/broken'
            ? 503
            : 200
    response.end('invalid JSON')
  })
  const api = new HubApi(80)
  await expect(api.request(url, '/conflict')).rejects.toMatchObject({
    kind: 'invalid-argument',
    message: '이미 있는 이름',
  })
  await expect(api.request(url, '/missing')).rejects.toMatchObject({ kind: 'not-found' })
  for (const path of ['/broken', '/json', '/timeout', '/body-timeout'])
    await expect(api.request(url, path)).rejects.toMatchObject({ kind: 'network' })
})
