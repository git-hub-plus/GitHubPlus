// Ported from GitHub Desktop (MIT): app/src/lib/git/checkout.ts
// Ported from GitHub Desktop (MIT): app/src/models/manual-conflict-resolution.ts
import { HandlerError } from '@shared/errors'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { AppFileStatusKind } from '@shared/models/status'
import { git } from './core'
import { validatePath } from './diff'
import { getStatus } from './status'
import { runOperation } from './merge'
import { cleanupRebaseEditor, rebaseEditorEnvironment } from './rebase'

export async function markResolved(repoPath: string, paths: ReadonlyArray<string>): Promise<void> {
  paths.forEach((path) => validatePath(repoPath, path))
  if (paths.length)
    await git(['--literal-pathspecs', 'add', '-A', '--', ...paths], repoPath, 'markResolved')
}

export async function resolveConflict(
  repoPath: string,
  path: string,
  choice: 'ours' | 'theirs'
): Promise<void> {
  validatePath(repoPath, path)
  if (choice !== 'ours' && choice !== 'theirs')
    throw new HandlerError('invalid-argument', 'Invalid conflict choice')
  const entries = (
    await git(
      ['--literal-pathspecs', 'ls-files', '-u', '-z', '--', path],
      repoPath,
      'conflictStages'
    )
  ).stdout
    .split('\0')
    .filter(Boolean)
  if (!entries.length) throw new HandlerError('invalid-argument', 'File is not conflicted')
  const stage = choice === 'ours' ? '2' : '3'
  if (entries.some((entry) => entry.slice(0, entry.indexOf('\t')).endsWith(` ${stage}`))) {
    await git(
      ['--literal-pathspecs', 'checkout', `--${choice}`, '--', path],
      repoPath,
      'resolveConflict'
    )
    await markResolved(repoPath, [path])
  } else {
    await git(['--literal-pathspecs', 'rm', '-f', '--', path], repoPath, 'resolveDeletedConflict')
  }
}

export async function continueOperation(
  repoPath: string,
  opts?: { message?: string }
): Promise<OperationOutcome> {
  const status = await getStatus(repoPath)
  if (status.files.some((file) => file.status.kind === AppFileStatusKind.Conflicted))
    return 'conflicts'
  if (!status.inProgress) return 'nothing-to-do'
  const kind = status.inProgress.kind
  const result = await runOperation(
    repoPath,
    kind === 'merge'
      ? ['commit', ...(opts?.message !== undefined ? ['-m', opts.message] : ['--no-edit'])]
      : [kind, '--continue'],
    { env: kind === 'rebase' ? await rebaseEditorEnvironment(repoPath) : undefined }
  )
  if (kind === 'rebase') await cleanupRebaseEditor(repoPath)
  return result
}

export async function abortOperation(repoPath: string): Promise<void> {
  const operation = (await getStatus(repoPath)).inProgress
  if (!operation) return
  await git([operation.kind, '--abort'], repoPath, 'abortOperation')
  if (operation.kind === 'rebase') await cleanupRebaseEditor(repoPath)
}
