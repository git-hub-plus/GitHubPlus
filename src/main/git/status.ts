// Ported from GitHub Desktop (MIT): app/src/lib/git/status.ts
// Ported from GitHub Desktop (MIT): app/src/lib/git/stash.ts (count only)
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import {
  AppFileStatusKind as Kind,
  UnmergedEntrySummary,
  type RepoStatus,
} from '@shared/models/status'
import { git } from './core'
import { isStatusEntry, isStatusHeader, mapStatus, parsePorcelainStatus } from './status-parser'
import { getInProgress } from './in-progress'

export async function getStatus(repoPath: string): Promise<RepoStatus> {
  const [result, stash, inProgress] = await Promise.all([
    git(
      ['--no-optional-locks', 'status', '--porcelain=2', '--branch', '--untracked-files=all', '-z'],
      repoPath,
      'getStatus'
    ),
    git(['stash', 'list', '--format=%H'], repoPath, 'countStashes'),
    getInProgress(repoPath),
  ])
  const entries = parsePorcelainStatus(result.stdout)
  const headers = new Map(
    entries.filter(isStatusHeader).map(({ value }) => {
      const space = value.indexOf(' ')
      return [value.slice(0, space), value.slice(space + 1)]
    })
  )
  const head = headers.get('branch.oid')
  const branch = headers.get('branch.head')
  const ab = /^\+(\d+) -(\d+)$/.exec(headers.get('branch.ab') ?? '')
  const files = await Promise.all(
    entries.filter(isStatusEntry).map(async (entry) => {
      let status = mapStatus(
        entry.statusCode,
        entry.submoduleStatusCode,
        entry.renameOrCopyScore,
        entry.oldPath
      )
      if (
        status.kind === Kind.Conflicted &&
        [UnmergedEntrySummary.BothAdded, UnmergedEntrySummary.BothModified].includes(status.action)
      ) {
        try {
          const content = await readFile(join(repoPath, entry.path))
          if (!content.includes(0)) {
            const attr = await git(
              ['check-attr', '-z', 'conflict-marker-size', 'diff', '--', entry.path],
              repoPath,
              'conflictAttributes'
            )
            const attrs = attr.stdout.split('\0')
            const size = /^\d+$/.test(attrs[2]) ? Math.max(1, Number(attrs[2])) : 7
            if (attrs[5] !== 'unset')
              status = {
                ...status,
                conflictMarkerCount: (
                  content.toString().match(new RegExp(`^<{${size}}(?: |$)`, 'gm')) ?? []
                ).length,
              }
          }
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
        }
      }
      return { path: entry.path, status }
    })
  )
  return {
    currentBranch: branch && !branch.startsWith('(') ? branch : undefined,
    headSha: head && head !== '(initial)' ? head : undefined,
    upstream: headers.get('branch.upstream'),
    ahead: ab ? Number(ab[1]) : 0,
    behind: ab ? Number(ab[2]) : 0,
    files,
    inProgress,
    stashCount: stash.stdout.split('\n').filter(Boolean).length,
  }
}
