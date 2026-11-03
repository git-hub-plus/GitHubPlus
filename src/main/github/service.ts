import { setTimeout as delay } from 'node:timers/promises'
import { HandlerError } from '@shared/errors'
import type { DeviceFlowStart, GitHubAccount, GitHubRepository } from '@shared/ipc/integrations'
import type { TokenStore } from './token-store'

interface Options {
  clientId: string
  tokens: TokenStore
  fetch?: typeof fetch
  now?: () => number
  wait?: (ms: number, signal: AbortSignal) => Promise<void>
}
interface Flow {
  controller: AbortController
  deviceCode?: string
  expiresAt: number
  interval: number
  completion?: Promise<GitHubAccount>
}
interface User {
  login: string
  name?: string | null
  avatar_url?: string
}
interface RemoteRepository {
  full_name: string
  clone_url: string
  private: boolean
  description?: string | null
  updated_at: string
}

/** Injectable HTTP/clock boundaries keep Device Flow independent of Electron. */
export class GitHubService {
  private readonly fetcher: typeof fetch
  private readonly now: () => number
  private readonly wait: NonNullable<Options['wait']>
  private flow?: Flow
  private generation = 0

  public constructor(private readonly options: Options) {
    this.fetcher = options.fetch ?? fetch
    this.now = options.now ?? Date.now
    this.wait = options.wait ?? ((ms, signal) => delay(ms, undefined, { signal }))
  }

  private clientId(): string {
    if (!this.options.clientId) {
      throw new HandlerError('invalid-argument', 'GitHub OAuth App client id가 설정되지 않았습니다')
    }
    return this.options.clientId
  }

  private async request(url: string, init: RequestInit): Promise<Response> {
    try {
      return await this.fetcher(url, {
        ...init,
        signal: init.signal ?? AbortSignal.timeout(30_000),
        redirect: 'error',
      })
    } catch {
      // Never expose fetch errors: injected transports may include request headers.
      throw new HandlerError('network', 'GitHub에 연결하지 못했습니다')
    }
  }

  private async json<T>(response: Response): Promise<T> {
    try {
      return (await response.json()) as T
    } catch {
      throw new HandlerError('network', 'GitHub 응답을 읽지 못했습니다')
    }
  }

  public async beginDeviceFlow(): Promise<DeviceFlowStart> {
    const clientId = this.clientId()
    this.cancelDeviceFlow()
    const flow: Flow = { controller: new AbortController(), expiresAt: 0, interval: 5 }
    this.flow = flow
    try {
      const response = await this.request('https://github.com/login/device/code', {
        method: 'POST',
        headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
        body: JSON.stringify({ client_id: clientId, scope: 'repo read:user' }),
        signal: AbortSignal.any([flow.controller.signal, AbortSignal.timeout(30_000)]),
      })
      if (!response.ok)
        throw new HandlerError('authentication-failed', 'GitHub 로그인을 시작하지 못했습니다')
      const data = await this.json<{
        device_code: string
        user_code: string
        verification_uri: string
        expires_in: number
        interval: number
      }>(response)
      if (flow.controller.signal.aborted)
        throw new HandlerError('invalid-argument', 'GitHub 로그인을 취소했습니다')
      if (
        !data.device_code ||
        !data.user_code ||
        data.verification_uri !== 'https://github.com/login/device' ||
        !(data.expires_in > 0) ||
        !(data.interval > 0)
      ) {
        throw new HandlerError('authentication-failed', 'GitHub 로그인 응답이 올바르지 않습니다')
      }
      flow.deviceCode = data.device_code
      flow.expiresAt = this.now() + data.expires_in * 1000
      flow.interval = data.interval
      return {
        userCode: data.user_code,
        verificationUri: data.verification_uri,
        expiresAt: flow.expiresAt,
        intervalSeconds: flow.interval,
      }
    } catch (error) {
      if (this.flow === flow) this.flow = undefined
      throw error
    }
  }

  public completeDeviceFlow(): Promise<GitHubAccount> {
    const flow = this.flow
    if (!flow?.deviceCode)
      return Promise.reject(new HandlerError('invalid-argument', '먼저 GitHub 로그인을 시작하세요'))
    flow.completion ??= this.poll(flow).finally(() => {
      if (this.flow === flow) this.flow = undefined
    })
    return flow.completion
  }

  private check(flow: Flow): void {
    if (flow.controller.signal.aborted)
      throw new HandlerError('invalid-argument', 'GitHub 로그인을 취소했습니다')
    if (this.now() >= flow.expiresAt)
      throw new HandlerError('authentication-failed', 'GitHub 로그인 코드가 만료되었습니다')
  }

  private async poll(flow: Flow): Promise<GitHubAccount> {
    try {
      while (true) {
        this.check(flow)
        await this.wait(
          Math.min(flow.interval * 1000, flow.expiresAt - this.now()),
          flow.controller.signal
        )
        this.check(flow)
        const response = await this.request('https://github.com/login/oauth/access_token', {
          method: 'POST',
          headers: { Accept: 'application/json', 'Content-Type': 'application/json' },
          body: JSON.stringify({
            client_id: this.clientId(),
            device_code: flow.deviceCode,
            grant_type: 'urn:ietf:params:oauth:grant-type:device_code',
          }),
          signal: AbortSignal.any([
            flow.controller.signal,
            AbortSignal.timeout(Math.min(30_000, flow.expiresAt - this.now())),
          ]),
        })
        const data = await this.json<{ error?: string; access_token?: string }>(response)
        this.check(flow)
        if (data.error === 'authorization_pending') continue
        if (data.error === 'slow_down') {
          flow.interval += 5
          continue
        }
        if (data.error === 'expired_token')
          throw new HandlerError('authentication-failed', 'GitHub 로그인 코드가 만료되었습니다')
        if (data.error === 'access_denied')
          throw new HandlerError('authentication-failed', 'GitHub 로그인이 거부되었습니다')
        if (!response.ok || !data.access_token || data.error)
          throw new HandlerError('authentication-failed', 'GitHub 로그인에 실패했습니다')
        // Verify the account before making the token available to git or persisting it.
        const userResponse = await this.request('https://api.github.com/user', {
          headers: this.headers(data.access_token),
          signal: AbortSignal.any([flow.controller.signal, AbortSignal.timeout(30_000)]),
        })
        if (!userResponse.ok)
          throw new HandlerError('authentication-failed', 'GitHub 계정을 확인하지 못했습니다')
        const user = await this.json<User>(userResponse)
        this.check(flow)
        await this.options.tokens.set(data.access_token)
        if (flow.controller.signal.aborted) {
          if (this.options.tokens.get() === data.access_token) await this.options.tokens.clear()
          this.check(flow)
        }
        return this.mapUser(user)
      }
    } catch (error) {
      this.check(flow)
      if (error instanceof HandlerError) throw error
      throw new HandlerError('network', 'GitHub 로그인에 실패했습니다')
    }
  }

  public cancelDeviceFlow(): void {
    this.flow?.controller.abort()
    this.flow = undefined
  }

  public async signOut(): Promise<void> {
    this.generation++
    this.cancelDeviceFlow()
    await this.options.tokens.clear()
  }

  private headers(token: string): Record<string, string> {
    return {
      Accept: 'application/vnd.github+json',
      Authorization: `Bearer ${token}`,
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    }
  }

  private async apiResponse(url: string, init: RequestInit = {}): Promise<Response> {
    const target = new URL(url)
    if (target.origin !== 'https://api.github.com' || target.username || target.password)
      throw new HandlerError('invalid-argument', 'GitHub API 주소가 올바르지 않습니다')
    const token = this.options.tokens.get()
    if (!token) throw new HandlerError('authentication-failed', '먼저 GitHub에 로그인하세요')
    const generation = this.generation
    const response = await this.request(url, { ...init, headers: this.headers(token) })
    if (response.status === 401) {
      if (this.options.tokens.get() === token && this.generation === generation)
        await this.signOut()
      throw new HandlerError(
        'authentication-failed',
        'GitHub 인증이 만료되었습니다. 다시 로그인하세요'
      )
    }
    if (generation !== this.generation || token !== this.options.tokens.get())
      throw new HandlerError('authentication-failed', 'GitHub 계정이 변경되었습니다')
    if (!response.ok)
      throw new HandlerError(
        response.status === 422 ? 'invalid-argument' : 'network',
        `GitHub 요청에 실패했습니다 (${response.status})`
      )
    return response
  }

  public async api<T>(url: string, init?: RequestInit): Promise<T> {
    return this.json<T>(await this.apiResponse(url, init))
  }

  private mapUser(user: User): GitHubAccount {
    return { login: user.login, name: user.name ?? undefined, avatarUrl: user.avatar_url }
  }

  public async account(): Promise<GitHubAccount | null> {
    if (!this.options.tokens.get()) return null
    return this.mapUser(await this.api<User>('https://api.github.com/user'))
  }

  public async repositories(): Promise<ReadonlyArray<GitHubRepository>> {
    const repos: GitHubRepository[] = []
    let next: string | undefined = 'https://api.github.com/user/repos?per_page=100&sort=updated'
    const seen = new Set<string>()
    while (next && !seen.has(next)) {
      seen.add(next)
      const response = await this.apiResponse(next)
      const data = await this.json<RemoteRepository[]>(response)
      repos.push(
        ...data.map((repo) => ({
          fullName: repo.full_name,
          cloneUrl: repo.clone_url,
          private: repo.private,
          description: repo.description ?? undefined,
          updatedAt: Date.parse(repo.updated_at),
        }))
      )
      next = response.headers
        .get('Link')
        ?.split(',')
        .map((link) => link.match(/<([^>]+)>;\s*rel="next"/))
        .find(Boolean)?.[1]
    }
    return repos
  }
}
