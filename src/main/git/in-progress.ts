// Ported from GitHub Desktop (MIT): app/src/lib/git/merge.ts
// Ported from GitHub Desktop (MIT): app/src/lib/git/rebase.ts
// Ported from GitHub Desktop (MIT): app/src/lib/git/cherry-pick.ts
import { readFile } from 'node:fs/promises'
import { join } from 'node:path'
import type { InProgressOperation } from '@shared/models/status'
import { getGitPath } from './rev-parse'
import { git } from './core'
async function read(path: string): Promise<string | undefined> {
  try {
    return (await readFile(path, 'utf8')).trim()
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined
    throw error
  }
}
export async function getInProgress(repoPath: string): Promise<InProgressOperation | undefined> {
  const gitDir = await getGitPath(repoPath, '.')
  for (const directory of ['rebase-merge', 'rebase-apply']) {
    const root = join(gitDir, directory)
    const head = await read(join(root, 'head-name'))
    if (head !== undefined) {
      const merge = directory === 'rebase-merge'
      return {
        kind: 'rebase',
        targetBranch: head.replace(/^refs\/heads\//, ''),
        baseBranch: await read(join(root, 'onto')),
        step: Number(await read(join(root, merge ? 'msgnum' : 'next'))) || 0,
        totalSteps: Number(await read(join(root, merge ? 'end' : 'last'))) || 0,
      }
    }
  }
  if (await read(join(gitDir, 'MERGE_HEAD'))) return { kind: 'merge' }
  const todo = await read(join(gitDir, 'sequencer/todo'))
  const commands = todo?.split('\n').filter((line) => /^(pick|revert) /.test(line)) ?? []
  if (
    (await read(join(gitDir, 'CHERRY_PICK_HEAD'))) ||
    commands.some((line) => line.startsWith('pick '))
  ) {
    const head = await read(join(gitDir, 'sequencer/head'))
    const safety = await read(join(gitDir, 'sequencer/abort-safety'))
    let completed = 0
    if (head && safety && head !== safety) {
      const count = await git(
        ['rev-list', '--count', '--end-of-options', `${head}..${safety}`, '--'],
        repoPath,
        'cherryPickProgress'
      )
      completed = Number(count.stdout.trim()) || 0
    }
    return {
      kind: 'cherry-pick',
      step: completed + 1,
      totalSteps: completed + Math.max(commands.length, 1),
    }
  }
  if (
    (await read(join(gitDir, 'REVERT_HEAD'))) ||
    commands.some((line) => line.startsWith('revert '))
  )
    return { kind: 'revert' }
  return undefined
}
