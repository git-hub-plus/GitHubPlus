// Ported from GitHub Desktop (MIT): app/src/lib/git/log.ts
import type { LogQuery } from '@shared/ipc/git'
import type { Commit, CommitIdentity, CommittedFile } from '@shared/models/git'
import { AppFileStatusKind as Kind, type AppFileStatus } from '@shared/models/status'
import { git } from './core'
import { createLogParser } from './git-delimiter-parser'
import { resolveCommit } from './rev-parse'

function identity(name: string, email: string, raw: string): CommitIdentity {
  const match = /^(\d+) ([+-])(\d{2})(\d{2})$/.exec(raw)
  if (!match) throw new Error('Malformed commit date')
  return {
    name,
    email,
    date: Number(match[1]) * 1000,
    tzOffset: (match[2] === '-' ? -1 : 1) * (Number(match[3]) * 60 + Number(match[4])),
  }
}

export async function getCommits(repoPath: string, query: LogQuery): Promise<Commit[]> {
  if (
    !Number.isSafeInteger(query.limit) ||
    query.limit < 0 ||
    !Number.isSafeInteger(query.skip ?? 0) ||
    (query.skip ?? 0) < 0
  )
    throw new Error('Invalid history pagination')
  if (query.limit === 0) return []
  // Only an unborn default HEAD is empty; invalid explicit revisions must fail.
  if (!query.all && query.ref === undefined && !(await resolveCommit(repoPath))) return []
  const { formatArgs, parse } = createLogParser({
    sha: '%H',
    shortSha: '%h',
    summary: '%s',
    body: '%b',
    authorName: '%an',
    authorEmail: '%ae',
    authorDate: '%ad',
    committerName: '%cn',
    committerEmail: '%ce',
    committerDate: '%cd',
    parents: '%P',
    refs: '%D',
  })
  const args = [
    'log',
    '--date=raw',
    '--no-color',
    '--no-show-signature',
    '--decorate=full',
    '--topo-order',
    `--max-count=${query.limit}`,
    `--skip=${query.skip ?? 0}`,
    ...formatArgs,
  ]
  if (query.all) args.push('--all')
  // --full-history prevents path simplification from replacing parent identities.
  if (query.path !== undefined) args.push('--full-history')
  if (query.ref !== undefined) args.push('--end-of-options', query.ref)
  args.push('--')
  if (query.path !== undefined) args.push(`:(literal)${query.path}`)
  const result = await git(args, repoPath, 'getCommits')
  return parse(result.stdout).map((entry) => ({
    sha: entry.sha,
    shortSha: entry.shortSha,
    summary: entry.summary,
    body: entry.body,
    author: identity(entry.authorName, entry.authorEmail, entry.authorDate),
    committer: identity(entry.committerName, entry.committerEmail, entry.committerDate),
    parentShas: entry.parents ? entry.parents.split(' ') : [],
    tags: entry.refs
      .split(', ')
      .flatMap((ref) =>
        ref.startsWith('tag: refs/tags/') ? [ref.slice('tag: refs/tags/'.length)] : []
      ),
  }))
}

/** Diff a merge against exactly its first parent; include root commit additions. */
export async function getCommitFiles(repoPath: string, sha: string): Promise<CommittedFile[]> {
  const resolved = await resolveCommit(repoPath, sha)
  if (!resolved) throw new Error(`Unknown commit: ${sha}`)
  const parents = await git(
    ['rev-list', '--parents', '-n', '1', resolved, '--'],
    repoPath,
    'commitParents'
  )
  const firstParent = parents.stdout.trim().split(' ')[1]
  const args = firstParent
    ? ['diff', '--raw', '-z', '-M', firstParent, resolved, '--']
    : ['diff-tree', '--root', '--no-commit-id', '-r', '--raw', '-z', '-M', resolved, '--']
  const result = await git(args, repoPath, 'getCommitFiles')
  const tokens = result.stdout.split('\0')
  const files: CommittedFile[] = []
  for (let i = 0; i < tokens.length && tokens[i];) {
    const match = /^:(\d+) (\d+) [a-f0-9]+ [a-f0-9]+ ([A-Z])(\d*)$/.exec(tokens[i++])
    if (!match) throw new Error('Malformed raw commit diff')
    const [, sourceMode, targetMode, code, score] = match
    const source = tokens[i++]
    const renamed = code === 'R' || code === 'C'
    const path = renamed ? tokens[i++] : source
    const submoduleStatus =
      sourceMode === '160000' || targetMode === '160000'
        ? {
            commitChanged: code === 'M',
            modifiedChanges: false,
            untrackedChanges: false,
          }
        : undefined
    const status: AppFileStatus = renamed
      ? {
          kind: code === 'R' ? Kind.Renamed : Kind.Copied,
          oldPath: source,
          renameIncludesModifications: score !== '100',
          submoduleStatus,
        }
      : {
          kind: code === 'A' ? Kind.New : code === 'D' ? Kind.Deleted : Kind.Modified,
          submoduleStatus,
        }
    files.push({ path, status })
  }
  return files
}
