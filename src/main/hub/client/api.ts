import { HandlerError } from '@shared/errors'
import type { HubRepository } from '@shared/ipc/hub'
import type { Commit, CommittedFile } from '@shared/models/git'
import type { FileDiff } from '@shared/models/diff'

export function normalizeHubUrl(input: string): string {
  try {
    input = input.trim()
    const url = new URL(input.includes('://') ? input : `http://${input}`)
    if (
      !['http:', 'https:'].includes(url.protocol) ||
      url.username ||
      url.password ||
      url.pathname !== '/' ||
      url.search ||
      url.hash
    )
      throw new Error('Invalid hub URL')
    return url.origin
  } catch {
    throw new HandlerError('invalid-argument', '허브 주소를 확인하세요.')
  }
}

/** JSON requests never follow redirects; each call has a bounded lifetime, including its body. */
export class HubApi {
  constructor(private readonly timeoutMs = 5000) {}

  async request<T>(hubUrl: string, path: string, body?: unknown): Promise<T> {
    const base = normalizeHubUrl(hubUrl)
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), this.timeoutMs)
    try {
      const response = await fetch(`${base}${path}`, {
        method: body === undefined ? 'GET' : 'POST',
        headers: {
          Accept: 'application/json',
          ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: controller.signal,
        redirect: 'error',
      })
      if (response.status === 409) throw new HandlerError('invalid-argument', '이미 있는 이름')
      if (!response.ok)
        throw new HandlerError(
          response.status === 404
            ? 'not-found'
            : response.status === 400
              ? 'invalid-argument'
              : 'network',
          `허브 요청 실패 (${response.status})`
        )
      return (await response.json()) as T
    } catch (error) {
      if (error instanceof HandlerError) throw error
      throw new HandlerError(
        'network',
        '허브에 연결할 수 없습니다.',
        controller.signal.aborted
          ? '5초 안에 응답하지 않았습니다.'
          : error instanceof Error
            ? error.message
            : String(error)
      )
    } finally {
      clearTimeout(timer)
    }
  }

  info(url: string) {
    return this.request<{ name: string; version: string }>(url, '/api/info')
  }
  list(url: string) {
    return this.request<HubRepository[]>(url, '/api/repos')
  }
  create(url: string, name: string, description?: string) {
    if (
      !/^[\p{L}\p{N}_-][\p{L}\p{N}_.-]{0,99}$/u.test(name) ||
      name.endsWith('.git') ||
      name.includes('..')
    )
      throw new HandlerError('invalid-argument', '저장소 이름을 확인하세요.')
    return this.request<HubRepository>(url, '/api/repos', { name, description })
  }
  log(url: string, name: string, query: { ref?: string; limit: number; skip?: number }) {
    const params = new URLSearchParams({
      limit: String(query.limit),
      skip: String(query.skip ?? 0),
    })
    if (query.ref) params.set('ref', query.ref)
    return this.request<Commit[]>(url, `/api/repos/${encodeURIComponent(name)}/log?${params}`)
  }
  files(url: string, name: string, sha: string) {
    return this.request<CommittedFile[]>(
      url,
      `/api/repos/${encodeURIComponent(name)}/commits/${encodeURIComponent(sha)}/files`
    )
  }
  diff(url: string, name: string, sha: string, path: string) {
    return this.request<FileDiff>(
      url,
      `/api/repos/${encodeURIComponent(name)}/commits/${encodeURIComponent(sha)}/diff?${new URLSearchParams({ path })}`
    )
  }
}
