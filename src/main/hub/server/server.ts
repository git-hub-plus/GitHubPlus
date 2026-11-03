import { createServer, type IncomingMessage, type ServerResponse, type Server } from 'node:http'
import { appendFile, lstat, mkdir, readFile, readdir, rename, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { networkInterfaces } from 'node:os'
import { reverse } from 'node:dns/promises'
import { createGunzip } from 'node:zlib'
import { exec, spawn } from 'dugite'
import type { HubPushRecord, HubRepository, HubServerStatus, HubSettings } from '@shared/ipc/hub'
import { HandlerError } from '@shared/errors'
import { getCommitFiles, getCommits } from '../../git/log'
import { getCommitDiff, getCommittedFile } from '../../git/diff'
import { isPrivateAddress, isValidRepositoryName } from '../shared/validation'
import { startAnnouncer } from './announcer'

class HttpError extends HandlerError {
  constructor(
    readonly status: number,
    message: string
  ) {
    super(
      status === 404
        ? 'not-found'
        : status >= 400 && status < 500
          ? 'invalid-argument'
          : 'internal',
      message
    )
  }
}

export async function runGit(args: string[], cwd: string): Promise<string> {
  const result = await exec(args, cwd)
  if (result.exitCode !== 0) throw new Error(result.stderr)
  return result.stdout
}

export class HubServer {
  private server?: Server
  private stopAnnouncements?: () => void
  private queues = new Map<string, Promise<unknown>>()
  private current: HubServerStatus
  constructor(
    public settings: HubSettings,
    private readonly version: string,
    private readonly events: {
      status: (status: HubServerStatus) => void
      push: (record: HubPushRecord) => void
      error: (error: unknown) => void
    },
    private readonly announce = true
  ) {
    this.current = { running: false, port: settings.port, addresses: [], repositoryCount: 0 }
  }

  status(): HubServerStatus {
    return {
      ...this.current,
      port: this.current.running ? this.current.port : this.settings.port,
      addresses: [...this.current.addresses],
    }
  }
  async refreshRepositoryCount(): Promise<void> {
    this.update({ repositoryCount: (await this.list()).length })
  }
  private update(patch: Partial<HubServerStatus>): void {
    this.current = { ...this.current, ...patch }
    this.events.status(this.status())
  }
  async start(): Promise<void> {
    if (this.server) return
    try {
      await mkdir(this.settings.rootDirectory, { recursive: true })
      const server = createServer((req, res) => {
        void this.route(req, res).catch((error: unknown) => {
          if (res.headersSent) {
            res.destroy()
            return
          }
          const status =
            error instanceof HttpError
              ? error.status
              : error instanceof HandlerError && error.kind === 'invalid-argument'
                ? 400
                : 500
          if (status === 500) this.events.error(error)
          this.json(res, status, {
            error: status === 500 ? 'Hub request failed' : (error as Error).message,
          })
        })
      })
      this.server = server
      await new Promise<void>((resolve, reject) => {
        server.once('error', reject)
        server.listen(this.settings.port, () => {
          server.removeListener('error', reject)
          resolve()
        })
      })
      server.on('error', (error) => {
        this.update({ error: error.message })
        this.events.error(error)
      })
      const bound = server.address()
      const port = typeof bound === 'object' && bound ? bound.port : this.settings.port
      const addresses = Object.values(networkInterfaces()).flatMap((items) =>
        (items ?? [])
          .filter(
            (i) =>
              !i.internal &&
              isPrivateAddress(i.address) &&
              (i.family === 'IPv4' || (parseInt(i.address.split(':')[0], 16) & 0xffc0) !== 0xfe80)
          )
          .map((i) => `http://${i.family === 'IPv6' ? `[${i.address}]` : i.address}:${port}`)
      )
      this.update({
        running: true,
        port,
        addresses,
        repositoryCount: (await this.list()).length,
        error: undefined,
      })
      if (this.announce)
        this.stopAnnouncements = startAnnouncer(this.settings.name, port, this.version)
    } catch (error) {
      await this.stop()
      this.update({ error: error instanceof Error ? error.message : String(error) })
    }
  }
  async stop(): Promise<void> {
    this.stopAnnouncements?.()
    this.stopAnnouncements = undefined
    const server = this.server
    this.server = undefined
    if (server)
      await new Promise<void>((resolve) => {
        const timeout = setTimeout(() => server.closeAllConnections(), 5000)
        timeout.unref()
        server.close(() => {
          clearTimeout(timeout)
          resolve()
        })
        server.closeIdleConnections()
      })
    await Promise.allSettled(this.queues.values())
    this.update({ running: false, addresses: [] })
  }
  private async locked<T>(name: string, action: () => Promise<T>): Promise<T> {
    const previous = this.queues.get(name) ?? Promise.resolve()
    const next = previous.catch(() => {}).then(action)
    this.queues.set(name, next)
    try {
      return await next
    } finally {
      if (this.queues.get(name) === next) this.queues.delete(name)
    }
  }
  private path(name: string): string {
    if (!isValidRepositoryName(name))
      throw new HandlerError('invalid-argument', 'Invalid repository name')
    return join(this.settings.rootDirectory, `${name}.git`)
  }
  private async existing(name: string): Promise<string> {
    const path = this.path(name)
    const stat = await lstat(path).catch(() => null)
    if (!stat?.isDirectory() || stat.isSymbolicLink())
      throw new HttpError(404, 'Repository not found')
    return path
  }
  private async repository(name: string): Promise<HubRepository> {
    const path = await this.existing(name)
    const description = (await readFile(join(path, 'description'), 'utf8').catch(() => '')).trim()
    const head = await runGit(['symbolic-ref', '--short', 'HEAD'], path).catch(() => '')
    const lastPushAt = (await this.pushLog({ repository: name, limit: 1 }))[0]?.at
    return {
      name,
      description,
      defaultBranch: head.trim() || undefined,
      lastPushAt,
      url: `${this.current.addresses[0] ?? `http://127.0.0.1:${this.status().port}`}/${name}.git`,
    }
  }
  async list(): Promise<HubRepository[]> {
    const entries = await readdir(this.settings.rootDirectory, { withFileTypes: true }).catch(
      (error: NodeJS.ErrnoException) => {
        if (error.code === 'ENOENT') return []
        throw error
      }
    )
    return Promise.all(
      entries
        .filter(
          (e) =>
            e.isDirectory() && e.name.endsWith('.git') && isValidRepositoryName(e.name.slice(0, -4))
        )
        .map((e) => this.repository(e.name.slice(0, -4)))
    )
  }
  async create(name: string, description?: string): Promise<HubRepository> {
    this.path(name)
    return this.locked(name.toLowerCase(), async () => {
      const path = this.path(name)
      if (description !== undefined && typeof description !== 'string')
        throw new HttpError(400, 'Invalid description')
      await mkdir(this.settings.rootDirectory, { recursive: true })
      try {
        await mkdir(path)
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'EEXIST')
          throw new HttpError(409, 'Repository already exists')
        throw error
      }
      await runGit(['init', '--bare', '--initial-branch=main', path], this.settings.rootDirectory)
      for (const [key, value] of Object.entries({
        'receive.denyNonFastForwards': 'true',
        'receive.denyDeletes': 'true',
        'core.logAllRefUpdates': 'true',
        'gc.reflogExpire': 'never',
        'gc.reflogExpireUnreachable': 'never',
        'http.receivepack': 'true',
        'core.hooksPath': join(path, 'hooks'),
      }))
        await runGit(['config', key, value], path)
      // denyDeletes only covers branches; this hook also protects tags.
      await writeFile(
        join(path, 'hooks', 'pre-receive'),
        '#!/bin/sh\nzero=0000000000000000000000000000000000000000\nwhile read old new ref; do\n  if test "$new" = "$zero"; then\n    echo "Hub history protection: deleting refs is forbidden" >&2; exit 1\n  fi\n  case "$ref" in\n    refs/tags/*) if test "$old" != "$zero"; then echo "Hub history protection: rewriting tags is forbidden" >&2; exit 1; fi ;;\n  esac\ndone\n',
        { mode: 0o755 }
      )
      await writeFile(join(path, 'description'), description ?? '', 'utf8')
      this.update({ repositoryCount: (await this.list()).length })
      return this.repository(name)
    })
  }
  async delete(name: string): Promise<void> {
    this.path(name)
    await this.locked(name.toLowerCase(), async () => {
      const path = await this.existing(name)
      const trash = join(this.settings.rootDirectory, '.trash')
      await mkdir(trash, { recursive: true })
      await rename(path, join(trash, `${name}-${Date.now()}-${crypto.randomUUID()}.git`))
      this.update({ repositoryCount: (await this.list()).length })
    })
  }
  async pushLog(query: { repository?: string; limit: number }): Promise<HubPushRecord[]> {
    if (!Number.isSafeInteger(query.limit) || query.limit < 0)
      throw new HandlerError('invalid-argument', 'Invalid push log limit')
    const lines = (
      await readFile(join(this.settings.rootDirectory, '.push-log.jsonl'), 'utf8').catch(
        (error: NodeJS.ErrnoException) => {
          if (error.code === 'ENOENT') return ''
          throw error
        }
      )
    )
      .trim()
      .split('\n')
    return lines
      .flatMap((line) => {
        try {
          return [JSON.parse(line) as HubPushRecord]
        } catch {
          return []
        }
      })
      .filter((r) => !query.repository || r.repository === query.repository)
      .reverse()
      .slice(0, query.limit)
  }
  private json(res: ServerResponse, status: number, value: unknown): void {
    res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' })
    res.end(JSON.stringify(value))
  }
  private async body(req: IncomingMessage): Promise<unknown> {
    req.setEncoding('utf8')
    let body = ''
    for await (const chunk of req) {
      body += String(chunk)
      if (Buffer.byteLength(body) > 65536) throw new HttpError(413, 'Request too large')
    }
    try {
      return JSON.parse(body)
    } catch {
      throw new HttpError(400, 'Invalid JSON')
    }
  }
  private async route(req: IncomingMessage, res: ServerResponse): Promise<void> {
    if (!isPrivateAddress(req.socket.remoteAddress ?? ''))
      throw new HttpError(403, 'LAN access only')
    const url = new URL(req.url ?? '/', 'http://hub')
    const parts = url.pathname
      .split('/')
      .filter(Boolean)
      .map((p) => {
        try {
          return decodeURIComponent(p)
        } catch {
          throw new HttpError(400, 'Invalid URL')
        }
      })
    if (req.method === 'GET' && url.pathname === '/api/info') {
      this.json(res, 200, { name: this.settings.name, version: this.version })
      return
    }
    if (url.pathname === '/api/repos') {
      if (req.method === 'GET') {
        this.json(res, 200, await this.list())
        return
      }
      if (req.method === 'POST') {
        const data = (await this.body(req)) as { name?: unknown; description?: string } | null
        if (!data || !isValidRepositoryName(data.name))
          throw new HttpError(400, 'Invalid repository name')
        this.json(res, 201, await this.create(data.name, data.description))
        return
      }
    }
    if (req.method === 'GET' && parts[0] === 'api' && parts[1] === 'repos' && parts[2]) {
      const path = await this.existing(parts[2])
      if (parts.length === 4 && parts[3] === 'log') {
        const number = (key: string, fallback: number): number => {
          const n = Number(url.searchParams.get(key) ?? fallback)
          if (!Number.isSafeInteger(n) || n < 0 || n > 100000)
            throw new HttpError(400, 'Invalid pagination')
          return n
        }
        this.json(
          res,
          200,
          await getCommits(path, {
            ref: url.searchParams.get('ref') || undefined,
            limit: Math.min(number('limit', 100), 1000),
            skip: number('skip', 0),
          })
        )
        return
      }
      if (parts.length === 6 && parts[3] === 'commits' && /^[a-f0-9]{40,64}$/i.test(parts[4])) {
        if (parts[5] === 'files') {
          this.json(res, 200, await getCommitFiles(path, parts[4]))
          return
        }
        if (parts[5] === 'diff') {
          const file = await getCommittedFile(path, parts[4], url.searchParams.get('path') ?? '')
          this.json(res, 200, await getCommitDiff(path, parts[4], file))
          return
        }
      }
    }
    if (parts[0]?.endsWith('.git')) {
      const name = parts[0].slice(0, -4)
      const advertise =
        req.method === 'GET' && parts.length === 3 && parts[1] === 'info' && parts[2] === 'refs'
      const service = advertise ? url.searchParams.get('service') : parts[1]
      if (
        (advertise || (req.method === 'POST' && parts.length === 2)) &&
        (service === 'git-upload-pack' || service === 'git-receive-pack')
      ) {
        await this.locked(name.toLowerCase(), async () => {
          const path = await this.existing(name)
          await this.rpc(req, res, name, path, service, advertise)
        })
        return
      }
    }
    throw new HttpError(404, 'Not found')
  }
  private async refs(path: string): Promise<Map<string, string>> {
    return new Map(
      (await runGit(['for-each-ref', '--format=%(refname) %(objectname)'], path))
        .trim()
        .split('\n')
        .filter(Boolean)
        .map((line) => line.trim().split(' ') as [string, string])
    )
  }
  private async rpc(
    req: IncomingMessage,
    res: ServerResponse,
    name: string,
    path: string,
    service: string,
    advertise: boolean
  ): Promise<void> {
    const receiving = !advertise && service === 'git-receive-pack'
    if (
      !advertise &&
      req.headers['content-encoding'] &&
      req.headers['content-encoding'] !== 'gzip' &&
      req.headers['content-encoding'] !== 'identity'
    )
      throw new HttpError(415, 'Unsupported content encoding')
    const before = receiving ? await this.refs(path) : new Map<string, string>()
    const child = spawn(
      [service.slice(4), '--stateless-rpc', ...(advertise ? ['--advertise-refs'] : []), path],
      path
    )
    res.writeHead(200, {
      'Content-Type': `application/x-${service}-${advertise ? 'advertisement' : 'result'}`,
      'Cache-Control': 'no-cache',
    })
    if (advertise) {
      const header = `# service=${service}\n`
      res.write(`${(Buffer.byteLength(header) + 4).toString(16).padStart(4, '0')}${header}0000`)
    }
    const abort = (): void => {
      child.kill()
    }
    res.on('close', abort)
    child.stderr.resume()
    child.stdout.pipe(res, { end: false })
    const closed = new Promise<void>((resolve, reject) => {
      child.once('error', reject)
      child.once('close', (code) =>
        code === 0 ? resolve() : reject(new Error(`${service} exited ${code}`))
      )
    })
    if (advertise) child.stdin.end()
    else if (req.headers['content-encoding'] === 'gzip') {
      const gunzip = createGunzip()
      gunzip.on('error', (error) => {
        child.kill()
        res.destroy(error)
      })
      req.pipe(gunzip).pipe(child.stdin)
    } else req.pipe(child.stdin)
    req.once('aborted', abort)
    try {
      await closed
      if (receiving) {
        const after = await this.refs(path)
        // Empty clones may use a client's configured initial branch (e.g. master).
        // Make the first published branch the default so later clones have a HEAD.
        if (![...before.keys()].some((ref) => ref.startsWith('refs/heads/'))) {
          const firstBranch = [...after.keys()].find((ref) => ref.startsWith('refs/heads/'))
          const head = (await runGit(['symbolic-ref', 'HEAD'], path)).trim()
          if (firstBranch && !after.has(head))
            await runGit(['symbolic-ref', 'HEAD', firstBranch], path)
        }
        const clientAddress = (req.socket.remoteAddress ?? '').replace(/^::ffff:/, '')
        // DNS is optional and must never delay completion of a push.
        const clientHost = await Promise.race([
          reverse(clientAddress.replace(/^::ffff:/, ''))
            .then((hosts) => hosts[0])
            .catch(() => undefined),
          new Promise<undefined>((resolve) => {
            const timer = setTimeout(() => resolve(undefined), 200)
            timer.unref()
          }),
        ])
        for (const [ref, newSha] of after)
          if (before.get(ref) !== newSha) {
            const record: HubPushRecord = {
              at: Date.now(),
              repository: name,
              ref,
              oldSha: before.get(ref) ?? '0'.repeat(newSha.length),
              newSha,
              clientAddress,
              clientHost,
            }
            await appendFile(
              join(this.settings.rootDirectory, '.push-log.jsonl'),
              `${JSON.stringify(record)}\n`,
              'utf8'
            )
            this.events.push(record)
          }
      }
      res.end()
    } finally {
      res.removeListener('close', abort)
      req.removeListener('aborted', abort)
    }
  }
}
