// Ported from GitHub Desktop (MIT): app/src/lib/git/reorder.ts
import { HandlerError } from '@shared/errors'
import { resolveCommit } from './diff'
import { historySelection, rebaseInteractive } from './rebase'

export async function reorder(
  repoPath: string,
  input: { shas: ReadonlyArray<string>; afterSha: string | null }
) {
  const { selected, commits, lines } = await historySelection(repoPath, input.shas)
  const after = input.afterSha === null ? null : await resolveCommit(repoPath, input.afterSha)
  if (after !== null && (!commits.includes(after) || selected.includes(after)))
    throw new HandlerError('invalid-argument', 'Invalid reorder destination')
  const rest = commits.filter((sha) => !selected.includes(sha))
  const insertAt = after === null ? 0 : rest.indexOf(after) + 1
  const ordered = [
    ...rest.slice(0, insertAt),
    ...commits.filter((sha) => selected.includes(sha)),
    ...rest.slice(insertAt),
  ]
  const start = commits.findIndex((sha, index) => sha !== ordered[index])
  if (start === -1) return 'nothing-to-do' as const
  return rebaseInteractive(
    repoPath,
    ordered
      .slice(start)
      .map((sha) => `pick ${sha}\n`)
      .join(''),
    lines[start][1] ?? null
  )
}
