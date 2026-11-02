// Ported from GitHub Desktop (MIT): app/src/lib/git/update-index.ts
import { getSelectionType } from '@shared/models/diff-selection'
import { AppFileStatusKind } from '@shared/models/status'
import { git, type GitOptions } from './core'
import { applyPatchToIndex, type SelectedFile } from './apply'

export async function updateIndex(
  repoPath: string,
  paths: ReadonlyArray<string>,
  forceRemove = false,
  options: GitOptions = {}
): Promise<void> {
  if (!paths.length) return
  await git(
    [
      'update-index',
      '--add',
      '--remove',
      '--replace',
      ...(forceRemove ? ['--force-remove'] : []),
      '-z',
      '--stdin',
    ],
    repoPath,
    'updateIndex',
    { ...options, stdin: `${paths.join('\0')}\0` }
  )
}

/** The supplied index must start from HEAD, matching the working diff baseline. */
export async function stageFiles(
  repoPath: string,
  files: ReadonlyArray<SelectedFile>,
  options: GitOptions = {}
): Promise<void> {
  const full = files.filter((f) => getSelectionType(f.selection) === 'all')
  await updateIndex(
    repoPath,
    full.flatMap((f) => (f.status.kind === AppFileStatusKind.Renamed ? [f.status.oldPath] : [])),
    true,
    options
  )
  await updateIndex(
    repoPath,
    full.map((f) => f.path),
    false,
    options
  )
  await updateIndex(
    repoPath,
    full.filter((f) => f.status.kind === AppFileStatusKind.Deleted).map((f) => f.path),
    true,
    options
  )
  for (const file of files) {
    if (getSelectionType(file.selection) === 'partial')
      await applyPatchToIndex(repoPath, file, options)
  }
}
