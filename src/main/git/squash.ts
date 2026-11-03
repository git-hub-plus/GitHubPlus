// Ported from GitHub Desktop (MIT): app/src/lib/git/squash.ts
import { HandlerError } from '@shared/errors'
import { historySelection, rebaseInteractive } from './rebase'

export async function squash(
  repoPath: string,
  input: { shas: ReadonlyArray<string>; message: string }
) {
  if (!input.message.trim())
    throw new HandlerError('invalid-argument', 'A squash message is required')
  const { selected, commits, lines } = await historySelection(repoPath, input.shas)
  if (selected.length < 2) throw new HandlerError('invalid-argument', 'Select at least two commits')
  const start = Math.min(...selected.map((sha) => commits.indexOf(sha)))
  const range = commits.slice(start)
  const picked = range.filter((sha) => selected.includes(sha))
  // Collect selected commits at the oldest selected position, preserving all others.
  const todo =
    picked.map((sha, index) => `${index === 0 ? 'reword' : 'fixup'} ${sha}\n`).join('') +
    range
      .filter((sha) => !selected.includes(sha))
      .map((sha) => `pick ${sha}\n`)
      .join('')
  return rebaseInteractive(repoPath, todo, lines[start][1] ?? null, input.message)
}
