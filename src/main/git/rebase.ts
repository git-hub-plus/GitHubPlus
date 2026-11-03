// Ported from GitHub Desktop (MIT): app/src/lib/git/rebase.ts
import { mkdir, readFile, writeFile, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { HandlerError } from '@shared/errors'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { git } from './core'
import { resolveCommit } from './diff'
import { getGitPath } from './rev-parse'
import { getStatus } from './status'
import { runOperation } from './merge'
import type { ProgressCallback } from './progress/from-process'

export async function assertNoMerges(repoPath: string, revisions: string[]): Promise<void> {
  const result = await git(
    ['rev-list', '--min-parents=2', ...revisions, '--'],
    repoPath,
    'validateLinearHistory'
  )
  if (result.stdout.trim())
    throw new HandlerError('invalid-argument', 'History editing cannot include merge commits')
}

/** Git invokes editors through its bundled POSIX shell, including on Windows. */
function quote(value: string): string {
  return `'${value.replace(/\\/g, '/').replace(/'/g, `'"'"'`)}'`
}
async function editorDirectory(repoPath: string): Promise<string> {
  return getGitPath(repoPath, 'ghp-advanced-rebase')
}
export async function rebaseEditorEnvironment(repoPath: string): Promise<Record<string, string>> {
  const directory = await editorDirectory(repoPath)
  try {
    await readFile(join(directory, 'message'), 'utf8')
    return {
      GIT_EDITOR: `${quote(process.execPath)} ${quote(join(directory, 'editor.cjs'))}`,
      ELECTRON_RUN_AS_NODE: '1',
    }
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error
    return { GIT_EDITOR: 'true' }
  }
}
export async function cleanupRebaseEditor(repoPath: string): Promise<void> {
  if ((await getStatus(repoPath)).inProgress?.kind === 'rebase') return
  await rm(await editorDirectory(repoPath), { recursive: true, force: true })
}

/** Todo includes the complete replay range; retained commits precede this range. */
export async function rebaseInteractive(
  repoPath: string,
  todo: string,
  retained: string | null,
  message?: string,
  progress?: ProgressCallback
): Promise<OperationOutcome> {
  if ((await getStatus(repoPath)).inProgress)
    throw new HandlerError('invalid-argument', 'An operation is already in progress')
  await assertNoMerges(repoPath, [retained ? `${retained}..HEAD` : 'HEAD'])
  const directory = await editorDirectory(repoPath)
  await rm(directory, { recursive: true, force: true })
  await mkdir(directory, { recursive: true })
  try {
    await writeFile(join(directory, 'todo'), todo)
    // No user data is interpolated into shell commands or executable source.
    await writeFile(
      join(directory, 'sequence.cjs'),
      "require('node:fs').copyFileSync(require('node:path').join(__dirname, 'todo'), process.argv[2])\n"
    )
    if (message !== undefined) {
      await writeFile(join(directory, 'message'), message)
      await writeFile(
        join(directory, 'editor.cjs'),
        // A later, unrelated pick may also open the editor after conflicts.
        // Only the selected reword/fixup commands receive the squash message.
        "const fs = require('node:fs'), path = require('node:path');\n" +
          "const done = fs.readFileSync(path.join(__dirname, '../rebase-merge/done'), 'utf8').trim().split('\\n').pop();\n" +
          "if (/^(reword|fixup) /.test(done)) fs.copyFileSync(path.join(__dirname, 'message'), process.argv[2]);\n"
      )
    }
    progress?.({ kind: 'generic', title: 'Rebasing', value: 0 })
    const result = await runOperation(
      repoPath,
      [
        '-c',
        'rebase.abbreviateCommands=false',
        '-c',
        'rebase.updateRefs=false',
        'rebase',
        '--interactive',
        '--force-rebase',
        '--keep-empty',
        ...(retained ? [retained] : ['--root']),
      ],
      {
        env: {
          ...(await rebaseEditorEnvironment(repoPath)),
          ELECTRON_RUN_AS_NODE: '1',
          GIT_SEQUENCE_EDITOR: `${quote(process.execPath)} ${quote(join(directory, 'sequence.cjs'))}`,
        },
        processCallback: (process) => {
          process.stderr?.on('data', (chunk: Buffer) => {
            for (const match of chunk.toString('utf8').matchAll(/Rebasing \((\d+)\/(\d+)\)/g)) {
              progress?.({
                kind: 'generic',
                title: 'Rebasing',
                value: Number(match[1]) / Math.max(1, Number(match[2])),
              })
            }
          })
        },
      }
    )
    if (result !== 'conflicts') progress?.({ kind: 'generic', title: 'Rebasing', value: 1 })
    return result
  } finally {
    await cleanupRebaseEditor(repoPath)
  }
}

export async function rebase(
  repoPath: string,
  baseBranch: string,
  progress?: ProgressCallback
): Promise<OperationOutcome> {
  const base = await resolveCommit(repoPath, baseBranch)
  const head = await resolveCommit(repoPath, 'HEAD')
  await assertNoMerges(repoPath, [`${base}..${head}`])
  const ancestor = await git(
    ['merge-base', '--is-ancestor', base, head],
    repoPath,
    'rebaseUpToDate',
    {
      successExitCodes: new Set([0, 1]),
    }
  )
  if (ancestor.exitCode === 0) return 'nothing-to-do'
  const commits = (
    await git(
      ['rev-list', '--reverse', '--topo-order', `${base}..${head}`, '--'],
      repoPath,
      'rebaseRange'
    )
  ).stdout
    .trim()
    .split('\n')
    .filter(Boolean)
  if (!commits.length) {
    // An ancestor branch may still need to fast-forward to the requested base.
    progress?.({ kind: 'generic', title: 'Rebasing', value: 0 })
    const result = await runOperation(repoPath, ['rebase', base])
    if (result !== 'conflicts') progress?.({ kind: 'generic', title: 'Rebasing', value: 1 })
    return result
  }
  return rebaseInteractive(
    repoPath,
    commits.map((sha) => `pick ${sha}\n`).join(''),
    base,
    undefined,
    progress
  )
}

/** Resolve and validate selections before writing any rebase state. */
export async function historySelection(repoPath: string, shas: ReadonlyArray<string>) {
  if (!shas.length) throw new HandlerError('invalid-argument', 'No commits selected')
  const selected = await Promise.all(shas.map((sha) => resolveCommit(repoPath, sha)))
  if (new Set(selected).size !== selected.length)
    throw new HandlerError('invalid-argument', 'Duplicate commits selected')
  const lines = (
    await git(
      ['rev-list', '--reverse', '--topo-order', '--parents', 'HEAD', '--'],
      repoPath,
      'historySelection'
    )
  ).stdout
    .trim()
    .split('\n')
    .filter(Boolean)
    .map((line) => line.split(' '))
  const commits = lines.map(([sha]) => sha)
  if (selected.some((sha) => !commits.includes(sha)))
    throw new HandlerError('invalid-argument', 'Selected commits must belong to HEAD')
  return { selected, commits, lines }
}
