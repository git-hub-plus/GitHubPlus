// Ported from GitHub Desktop (MIT): app/src/lib/git/apply.ts
import { HandlerError } from '@shared/errors'
import type { DiffSelectionData, FileDiff } from '@shared/models/diff'
import { getSelectionType } from '@shared/models/diff-selection'
import { AppFileStatusKind, type WorkingFile } from '@shared/models/status'
import { git, type GitOptions } from './core'
import { getWorkingDiff, oldPath } from './diff'
import { formatPatch, formatPatchToDiscardChanges } from './patch-formatter'

export type SelectedFile = WorkingFile & { readonly selection: DiffSelectionData }

function textDiff(diff: FileDiff) {
  if (diff.kind !== 'text' && diff.kind !== 'large') {
    throw new HandlerError('invalid-argument', `Cannot select lines in a ${diff.kind} diff`)
  }
  return diff
}

export async function applyPatchToIndex(
  repoPath: string,
  file: SelectedFile,
  options: GitOptions = {}
): Promise<void> {
  const diff = textDiff(await getWorkingDiff(repoPath, file))
  if ('oldPath' in file.status) {
    const entry = (
      await git(
        ['--literal-pathspecs', 'ls-tree', '-z', 'HEAD', '--', oldPath(file)],
        repoPath,
        'renameIndexBase',
        options
      )
    ).stdout
    const [mode, , oid] = entry.substring(0, entry.indexOf('\t')).split(' ')
    if (file.status.kind === AppFileStatusKind.Renamed) {
      await git(
        ['update-index', '--force-remove', '-z', '--stdin'],
        repoPath,
        'removeRenameSource',
        { ...options, stdin: `${oldPath(file)}\0` }
      )
    }
    await git(
      ['update-index', '--add', '--cacheinfo', mode, oid, file.path],
      repoPath,
      'renameIndexTarget',
      options
    )
  }
  await git(
    ['apply', '--cached', '--unidiff-zero', '--whitespace=nowarn', '-'],
    repoPath,
    'applyPatchToIndex',
    { ...options, stdin: formatPatch(file, diff) }
  )
}

export async function discardLines(
  repoPath: string,
  file: WorkingFile,
  selection: DiffSelectionData
): Promise<void> {
  if (getSelectionType(selection) === 'none') return
  const diff = textDiff(await getWorkingDiff(repoPath, file))
  const patch = formatPatchToDiscardChanges(file.path, diff, selection)
  if (patch === null) return
  await git(['apply', '--unidiff-zero', '--whitespace=nowarn', '-'], repoPath, 'discardLines', {
    stdin: patch,
  })
}
