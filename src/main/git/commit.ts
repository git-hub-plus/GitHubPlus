// Ported from GitHub Desktop (MIT): app/src/lib/git/commit.ts
import { mkdtemp, rm } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { HandlerError } from '@shared/errors'
import type { CommitInput } from '@shared/ipc/git'
import { getSelectionType } from '@shared/models/diff-selection'
import type { WorkingFile } from '@shared/models/status'
import { git } from './core'
import { headOrNull, oldPath, validatePath } from './diff'
import { stageFiles } from './update-index'

// Serialize our commits/discards per repository; Git's own index/ref locks also
// protect against other processes. Never reset the user's unrelated staged files.
const operations = new Map<string, Promise<unknown>>()
export async function withRepositoryOperation<T>(
  repoPath: string,
  operation: () => Promise<T>
): Promise<T> {
  const key = resolve(repoPath)
  const previous = operations.get(key) ?? Promise.resolve()
  const next = previous.catch(() => {}).then(operation)
  operations.set(key, next)
  try {
    return await next
  } finally {
    if (operations.get(key) === next) operations.delete(key)
  }
}

export async function createCommit(
  repoPath: string,
  input: CommitInput,
  workingFiles: ReadonlyArray<WorkingFile>
): Promise<string> {
  if (!input.summary.trim())
    throw new HandlerError('invalid-argument', 'A commit summary is required')
  const files = input.files
    .filter((f) => getSelectionType(f.selection) !== 'none')
    .map((f) => {
      validatePath(repoPath, f.path)
      const file = workingFiles.find((w) => w.path === f.path)
      if (!file) throw new HandlerError('not-found', `Changed file not found: ${f.path}`)
      validatePath(repoPath, oldPath(file))
      return { ...file, selection: f.selection }
    })
  if (!files.length && !input.amend)
    throw new HandlerError('invalid-argument', 'No changes selected')
  const head = await headOrNull(repoPath)
  const gitDir = resolve(
    repoPath,
    (await git(['rev-parse', '--absolute-git-dir'], repoPath, 'commitGitDir')).stdout.trim()
  )
  const tempDir = await mkdtemp(join(gitDir, 'ghp-commit-'))
  const options = { env: { GIT_INDEX_FILE: join(tempDir, 'index') } }
  try {
    await git(
      ['read-tree', ...(head ? [head] : ['--empty'])],
      repoPath,
      'initializeCommitIndex',
      options
    )
    await stageFiles(repoPath, files, options)
    const paths = [...new Set(files.flatMap((f) => [f.path, oldPath(f)]))]
    const allowed = new Set(paths)
    const staged = (
      await git(
        ['diff', '--cached', '--name-only', '--no-renames', '-z'],
        repoPath,
        'validateSelectedPaths',
        options
      )
    ).stdout
      .split('\0')
      .filter(Boolean)
    // update-index --replace can implicitly remove an ancestor/descendant when
    // a file becomes a directory (or vice versa). Require those paths explicitly.
    if (staged.some((path) => !allowed.has(path))) {
      throw new HandlerError(
        'invalid-argument',
        'Selection would change an unlisted file; select all affected paths'
      )
    }
    // Guard against an external commit while we were preparing the index.
    if ((await headOrNull(repoPath)) !== head)
      throw new HandlerError('invalid-argument', 'HEAD changed while preparing the commit; retry')
    const message = input.summary + (input.description ? `\n\n${input.description}` : '')
    await git(
      ['commit', '-F', '-', ...(input.amend ? ['--amend'] : [])],
      repoPath,
      'createCommit',
      { ...options, stdin: message }
    )
    const sha = (await git(['rev-parse', 'HEAD'], repoPath, 'newCommitSha')).stdout.trim()
    // Only reconcile selected paths in the real index. Other staged blobs stay
    // byte-for-byte as they were, and the working tree is never rewritten.
    if (paths.length) {
      const entries = (
        await git(
          ['--literal-pathspecs', 'ls-tree', '-z', sha, '--', ...paths],
          repoPath,
          'committedIndexEntries'
        )
      ).stdout
      const zero = '0'.repeat(sha.length)
      await git(['update-index', '-z', '--index-info'], repoPath, 'reconcileCommitIndex', {
        stdin: paths.map((p) => `0 ${zero}\t${p}\0`).join('') + entries,
      })
    }
    return sha
  } finally {
    await rm(tempDir, { recursive: true, force: true })
  }
}
