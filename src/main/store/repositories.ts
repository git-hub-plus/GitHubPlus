import { createHash } from 'node:crypto'
import { basename, join, resolve } from 'node:path'
import { app } from 'electron'
import type { RepositoryGroup, RepositoryInfo } from '@shared/models/app'
import { HandlerError } from '@shared/errors'
import { inspectRepository } from '../git/inspect'
import { readJson, writeJson } from './json-file'

let repositories: RepositoryInfo[] = []
const listeners = new Set<(list: ReadonlyArray<RepositoryInfo>) => void>()

function storePath(): string {
  return join(app.getPath('userData'), 'repositories.json')
}

/** Stable id derived from the normalized absolute path. */
export function repositoryId(path: string): string {
  const normalized = resolve(path).replace(/\\/g, '/')
  const key = process.platform === 'win32' ? normalized.toLowerCase() : normalized
  return createHash('sha1').update(key).digest('hex').slice(0, 16)
}

/** Hub URLs are registered by the hub module (N3); until then only GitHub is detected. */
const hubUrlMatchers: Array<(url: string) => boolean> = []

export function registerHubUrlMatcher(matcher: (url: string) => boolean): void {
  hubUrlMatchers.push(matcher)
}

export function groupForRemote(remoteUrl: string | undefined): RepositoryGroup {
  if (!remoteUrl) {
    return 'local'
  }
  if (hubUrlMatchers.some((match) => match(remoteUrl))) {
    return 'hub'
  }
  return /(^|[@/])github\.com[:/]/i.test(remoteUrl) ? 'github' : 'local'
}

async function persist(): Promise<void> {
  await writeJson(storePath(), repositories)
  for (const listener of listeners) {
    listener(repositories)
  }
}

export async function loadRepositories(): Promise<ReadonlyArray<RepositoryInfo>> {
  const stored = await readJson<RepositoryInfo[]>(storePath(), [])
  repositories = await Promise.all(
    stored.map(async (repo) => {
      const inspection = await inspectRepository(repo.path)
      return inspection
        ? {
            ...repo,
            available: true,
            remoteUrl: inspection.remoteUrl,
            group: groupForRemote(inspection.remoteUrl),
          }
        : { ...repo, available: false }
    })
  )
  return repositories
}

export function listRepositories(): ReadonlyArray<RepositoryInfo> {
  return repositories
}

export function getRepository(id: string): RepositoryInfo {
  const repo = repositories.find((r) => r.id === id)
  if (!repo) {
    throw new HandlerError('not-found', `Unknown repository: ${id}`)
  }
  return repo
}

export async function addRepository(path: string): Promise<RepositoryInfo> {
  const inspection = await inspectRepository(path)
  if (!inspection) {
    throw new HandlerError('not-a-repository', `${path} is not a Git repository`)
  }
  const id = repositoryId(inspection.root)
  const existing = repositories.find((r) => r.id === id)
  if (existing) {
    return existing
  }
  const repo: RepositoryInfo = {
    id,
    path: resolve(inspection.root),
    name: basename(inspection.root),
    group: groupForRemote(inspection.remoteUrl),
    remoteUrl: inspection.remoteUrl,
    pinned: false,
    addedAt: Date.now(),
    available: true,
  }
  repositories = [...repositories, repo]
  await persist()
  return repo
}

export async function updateRepository(
  id: string,
  patch: { alias?: string | null; pinned?: boolean; lastOpenedAt?: number; remoteUrl?: string }
): Promise<RepositoryInfo> {
  const repo = getRepository(id)
  const next: RepositoryInfo = {
    ...repo,
    alias: patch.alias === null ? undefined : (patch.alias ?? repo.alias),
    pinned: patch.pinned ?? repo.pinned,
    lastOpenedAt: patch.lastOpenedAt ?? repo.lastOpenedAt,
    remoteUrl: patch.remoteUrl ?? repo.remoteUrl,
    group: patch.remoteUrl !== undefined ? groupForRemote(patch.remoteUrl) : repo.group,
  }
  repositories = repositories.map((r) => (r.id === id ? next : r))
  await persist()
  return next
}

export async function removeRepository(id: string): Promise<void> {
  repositories = repositories.filter((r) => r.id !== id)
  await persist()
}

export function onRepositoriesChanged(
  listener: (list: ReadonlyArray<RepositoryInfo>) => void
): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}
