import { mkdtemp, readFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { TokenStore } from '../../../src/main/github/token-store'
import { GitHubService } from '../../../src/main/github/service'

const safeStorage = {
  isEncryptionAvailable: () => true,
  encryptString: (value: string) => Buffer.from(`encrypted:${value}`),
  decryptString: (value: Buffer) => value.toString().slice('encrypted:'.length),
}

const accountResponse = { login: 'octocat', name: 'Octocat', avatar_url: 'https://avatar.test/cat' }
const deviceResponse = {
  device_code: 'secret-device-code',
  user_code: 'ABCD-EFGH',
  verification_uri: 'https://github.com/login/device',
  expires_in: 900,
  interval: 5,
}

function json(value: unknown, status = 200, headers?: Record<string, string>): Response {
  return new Response(JSON.stringify(value), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  })
}

describe('GitHub Device Flow and API', () => {
  const directories: string[] = []

  afterEach(async () => {
    await Promise.all(
      directories.splice(0).map((path) => rm(path, { recursive: true, force: true }))
    )
  })

  async function setup(responses: Response[], options?: { clientId?: string; expiresIn?: number }) {
    const directory = await mkdtemp(join(tmpdir(), 'ghp-github-service-'))
    directories.push(directory)
    const tokens = new TokenStore(join(directory, 'token'), safeStorage)
    let now = 1_000
    const wait = vi.fn(async (milliseconds: number, signal: AbortSignal) => {
      if (signal.aborted) throw new Error('aborted')
      now += milliseconds
    })
    const fetch = vi.fn<typeof globalThis.fetch>()
    for (const response of responses) fetch.mockResolvedValueOnce(response)
    const service = new GitHubService({
      clientId: options?.clientId ?? 'client-id',
      tokens,
      fetch,
      now: () => now,
      wait,
    })
    return { directory, tokens, service, fetch, wait }
  }

  it('keeps the device code in main, waits for pending and slow_down, then stores the token', async () => {
    const { service, tokens, fetch, wait } = await setup([
      json(deviceResponse),
      json({ error: 'authorization_pending' }),
      json({ error: 'slow_down' }),
      json({ access_token: 'private-oauth-token', token_type: 'bearer' }),
      json(accountResponse),
    ])
    const start = await service.beginDeviceFlow()
    expect(start).toEqual({
      userCode: 'ABCD-EFGH',
      verificationUri: 'https://github.com/login/device',
      expiresAt: 901_000,
      intervalSeconds: 5,
    })
    const account = await service.completeDeviceFlow()
    expect(account).toEqual({
      login: 'octocat',
      name: 'Octocat',
      avatarUrl: 'https://avatar.test/cat',
    })
    expect(wait.mock.calls.map(([milliseconds]) => milliseconds)).toEqual([5000, 5000, 10000])
    expect(tokens.get()).toBe('private-oauth-token')
    expect(JSON.stringify(start)).not.toContain('secret-device-code')
    const [url, init] = fetch.mock.calls[0]
    expect(url).toBe('https://github.com/login/device/code')
    expect(new Headers(init?.headers).get('Accept')).toBe('application/json')
    expect(String(init?.body)).toContain('repo read:user')
    for (const [, request] of fetch.mock.calls.slice(1, 4)) {
      expect(String(request?.body)).toContain('urn:ietf:params:oauth:grant-type:device_code')
    }
  })

  it('rejects a missing OAuth client id before making a request', async () => {
    const { service, fetch } = await setup([], { clientId: '' })
    await expect(service.beginDeviceFlow()).rejects.toMatchObject({
      kind: 'invalid-argument',
      message: 'GitHub OAuth App client id가 설정되지 않았습니다',
    })
    expect(fetch).not.toHaveBeenCalled()
  })

  it.each(['expired_token', 'access_denied'])(
    'rejects %s without storing a token',
    async (error) => {
      const { service, tokens } = await setup([json(deviceResponse), json({ error })])
      await service.beginDeviceFlow()
      await expect(service.completeDeviceFlow()).rejects.toMatchObject({
        kind: 'authentication-failed',
      })
      expect(tokens.get()).toBeUndefined()
    }
  )

  it('stops polling when the device code expires locally', async () => {
    const { service, tokens, fetch } = await setup([json({ ...deviceResponse, expires_in: 1 })])
    await service.beginDeviceFlow()
    await expect(service.completeDeviceFlow()).rejects.toBeDefined()
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(tokens.get()).toBeUndefined()
  })

  it('cancels a waiting flow and never sends its token request', async () => {
    const { tokens, fetch } = await setup([json(deviceResponse)])
    let waiting!: () => void
    const entered = new Promise<void>((resolve) => (waiting = resolve))
    const wait = vi.fn((_ms: number, signal: AbortSignal) => {
      waiting()
      return new Promise<void>((_resolve, reject) => {
        signal.addEventListener('abort', () => reject(new Error('cancelled')), { once: true })
      })
    })
    const service = new GitHubService({ clientId: 'client-id', tokens, fetch, wait })
    await service.beginDeviceFlow()
    const completion = service.completeDeviceFlow()
    const rejected = expect(completion).rejects.toBeDefined()
    await entered
    service.cancelDeviceFlow()
    await rejected
    expect(fetch).toHaveBeenCalledTimes(1)
    expect(tokens.get()).toBeUndefined()
  })

  it('follows repository Link pages with authenticated versioned API requests', async () => {
    const first = {
      full_name: 'octocat/private',
      clone_url: 'https://github.com/octocat/private.git',
      private: true,
      description: 'private repository',
      updated_at: '2026-11-01T00:00:00Z',
    }
    const second = { ...first, full_name: 'octocat/public', private: false }
    const next = 'https://api.github.com/user/repos?page=2&per_page=100'
    const { service, tokens, fetch } = await setup([
      json([first], 200, { Link: `<${next}>; rel="next", <${next}>; rel="last"` }),
      json([second]),
    ])
    await tokens.set('private-oauth-token')
    expect(await service.repositories()).toEqual([
      {
        fullName: first.full_name,
        cloneUrl: first.clone_url,
        private: true,
        description: first.description,
        updatedAt: Date.parse(first.updated_at),
      },
      {
        fullName: second.full_name,
        cloneUrl: second.clone_url,
        private: false,
        description: second.description,
        updatedAt: Date.parse(second.updated_at),
      },
    ])
    expect(fetch.mock.calls[0][0]).toBe(
      'https://api.github.com/user/repos?per_page=100&sort=updated'
    )
    expect(fetch.mock.calls[1][0]).toBe(next)
    for (const [, init] of fetch.mock.calls) {
      const headers = new Headers(init?.headers)
      expect(headers.get('Authorization')).toBe('Bearer private-oauth-token')
      expect(headers.get('X-GitHub-Api-Version')).toBe('2022-11-28')
    }
  })

  it('clears persisted credentials on 401 without exposing a response token in the error', async () => {
    const { directory, service, tokens } = await setup([
      json({ message: 'private-oauth-token' }, 401),
    ])
    await tokens.set('private-oauth-token')
    const error = await service.repositories().catch((failure: unknown) => failure)
    expect(error).toMatchObject({ kind: 'authentication-failed' })
    expect(String(error)).not.toContain('private-oauth-token')
    expect(tokens.get()).toBeUndefined()
    await expect(readFile(join(directory, 'token'))).rejects.toMatchObject({ code: 'ENOENT' })
  })

  it('does not send a token to an untrusted pagination origin', async () => {
    const { service, tokens, fetch } = await setup([
      json([], 200, { Link: '<https://evil.test/repos>; rel="next"' }),
    ])
    await tokens.set('private-oauth-token')
    await expect(service.repositories()).rejects.toBeDefined()
    expect(fetch).toHaveBeenCalledTimes(1)
  })

  it('replaces transport errors containing token headers with a safe error', async () => {
    const { service, tokens, fetch } = await setup([])
    await tokens.set('private-oauth-token')
    fetch.mockRejectedValueOnce(new Error('Authorization: Bearer private-oauth-token'))
    const error = await service.account().catch((failure: unknown) => failure)
    expect(error).toMatchObject({ kind: 'network' })
    expect(String(error)).not.toContain('private-oauth-token')
    expect(JSON.stringify(error)).not.toContain('private-oauth-token')
  })

  it('shares one completion Promise and polling loop between concurrent callers', async () => {
    const { service, fetch } = await setup([
      json(deviceResponse),
      json({ access_token: 'private-oauth-token' }),
      json(accountResponse),
    ])
    await service.beginDeviceFlow()
    const first = service.completeDeviceFlow()
    const second = service.completeDeviceFlow()
    expect(second).toBe(first)
    expect(await first).toMatchObject({ login: 'octocat' })
    expect(await second).toMatchObject({ login: 'octocat' })
    expect(fetch).toHaveBeenCalledTimes(3)
  })

  it('ignores a token response arriving after cancellation during HTTP polling', async () => {
    const { service, tokens, fetch } = await setup([json(deviceResponse)])
    let respond!: (response: Response) => void
    let entered!: () => void
    const inFlight = new Promise<void>((resolve) => {
      entered = resolve
    })
    fetch.mockImplementationOnce(async () => {
      entered()
      // Deliberately ignore AbortSignal to model a transport resolving during cancellation.
      return new Promise<Response>((resolve) => {
        respond = resolve
      })
    })
    await service.beginDeviceFlow()
    const completion = service.completeDeviceFlow()
    const rejected = expect(completion).rejects.toBeDefined()
    await inFlight
    service.cancelDeviceFlow()
    respond(json({ access_token: 'private-oauth-token' }))
    await rejected
    expect(tokens.get()).toBeUndefined()
    expect(fetch).toHaveBeenCalledTimes(2)
  })
})
