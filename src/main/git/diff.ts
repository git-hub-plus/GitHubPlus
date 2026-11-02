// Ported from GitHub Desktop (MIT): app/src/lib/git/diff.ts
import { readFile } from 'node:fs/promises'
import { extname, isAbsolute, resolve, relative } from 'node:path'
import { HandlerError } from '@shared/errors'
import type { DiffImage, FileDiff, LineEnding } from '@shared/models/diff'
import type { CommittedFile } from '@shared/models/git'
import { AppFileStatusKind as Kind, type WorkingFile } from '@shared/models/status'
import { git } from './core'
import { DiffParser } from './diff-parser'

const MaxDiffBufferSize = 70e6
const MaxReasonableDiffSize = MaxDiffBufferSize / 16
const imageTypes: Record<string, string> = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.bmp': 'image/bmp',
  '.avif': 'image/avif',
}

export function validatePath(repoPath: string, path: string): void {
  const rel = relative(resolve(repoPath), resolve(repoPath, path))
  if (
    !path ||
    path.includes('\0') ||
    isAbsolute(path) ||
    rel === '..' ||
    rel.startsWith('../') ||
    rel.startsWith('..\\') ||
    isAbsolute(rel) ||
    !rel
  ) {
    throw new HandlerError('invalid-argument', `Invalid repository file path: ${path}`)
  }
}

export function oldPath(file: WorkingFile): string {
  return 'oldPath' in file.status ? file.status.oldPath : file.path
}

export async function resolveCommit(repoPath: string, revision: string): Promise<string> {
  return (
    await git(
      ['rev-parse', '--verify', '--end-of-options', `${revision}^{commit}`],
      repoPath,
      'resolveCommit'
    )
  ).stdout.trim()
}

export async function headOrNull(repoPath: string): Promise<string | null> {
  const result = await git(['rev-parse', '--verify', '--quiet', 'HEAD'], repoPath, 'headOrNull', {
    successExitCodes: new Set([0, 1]),
  })
  return result.exitCode === 0 ? result.stdout.trim() : null
}

export async function parentOrEmptyTree(repoPath: string, sha: string): Promise<string> {
  const parents = (
    await git(['rev-list', '--parents', '-n', '1', sha], repoPath, 'commitParent')
  ).stdout
    .trim()
    .split(' ')
  return parents[1] ?? (await git(['mktree'], repoPath, 'emptyTree', { stdin: '' })).stdout.trim()
}

const diffOptions = [
  '--no-ext-diff',
  '--no-textconv',
  '--no-color',
  '--no-renames',
  '--src-prefix=a/',
  '--dst-prefix=b/',
  '--unified=3',
  '--submodule=short',
]

/** HEAD-to-worktree diff, independent of the current index. */
export async function getWorkingDiff(repoPath: string, file: WorkingFile): Promise<FileDiff> {
  validatePath(repoPath, file.path)
  validatePath(repoPath, oldPath(file))
  const head = await headOrNull(repoPath)
  let args: string[]
  let successExitCodes = new Set([0])
  if (
    !file.status.submoduleStatus &&
    (file.status.kind === Kind.New || file.status.kind === Kind.Untracked || head === null)
  ) {
    args = ['diff', ...diffOptions, '--no-index', '--', '/dev/null', file.path]
    successExitCodes = new Set([0, 1])
  } else if ('oldPath' in file.status && head !== null) {
    // Compare blobs so staged edits of a renamed file are included too.
    const before = (
      await git(['rev-parse', '--verify', `${head}:${oldPath(file)}`], repoPath, 'renameBase')
    ).stdout.trim()
    const after = (
      await git(['hash-object', '-w', `--path=${file.path}`, '--stdin'], repoPath, 'renameTarget', {
        stdin: await readFile(resolve(repoPath, file.path)),
      })
    ).stdout.trim()
    args = ['diff', ...diffOptions, before, after, '--']
  } else {
    const base = head ?? (await git(['mktree'], repoPath, 'emptyTree', { stdin: '' })).stdout.trim()
    args = ['--literal-pathspecs', 'diff', ...diffOptions, base, '--', file.path]
  }
  const result = await git(args, repoPath, 'getWorkingDiff', {
    encoding: 'buffer',
    successExitCodes,
  })
  return buildDiff(repoPath, file, result.stdout, result.stderr, head, null)
}

export async function getCommitDiff(
  repoPath: string,
  sha: string,
  file: CommittedFile
): Promise<FileDiff> {
  validatePath(repoPath, file.path)
  validatePath(repoPath, oldPath(file))
  const commit = await resolveCommit(repoPath, sha)
  const parent = await parentOrEmptyTree(repoPath, commit)
  const { stdout, stderr } = await git(
    [
      '--literal-pathspecs',
      'diff',
      ...diffOptions,
      '-M',
      parent,
      commit,
      '--',
      file.path,
      oldPath(file),
    ],
    repoPath,
    'getCommitDiff',
    { encoding: 'buffer' }
  )
  return buildDiff(repoPath, file, stdout, stderr, parent, commit)
}

async function buildDiff(
  repoPath: string,
  file: WorkingFile,
  buffer: Buffer,
  stderr: Buffer,
  previousRef: string | null,
  currentRef: string | null
): Promise<FileDiff> {
  if (buffer.length > MaxDiffBufferSize) return { kind: 'unrenderable' }
  const raw = buffer.toString('utf8')
  if (
    file.status.submoduleStatus ||
    /(?:^|\n)(?:index .* 160000|(?:new|deleted) file mode 160000)(?:\n|$)/.test(raw)
  ) {
    const config = await git(
      ['config', '--get', `submodule.${file.path}.url`],
      repoPath,
      'submoduleUrl',
      { successExitCodes: new Set([0, 1]) }
    )
    return {
      kind: 'submodule',
      path: file.path,
      url: config.stdout.trim() || null,
      status: file.status.submoduleStatus ?? {
        commitChanged: true,
        modifiedChanges: false,
        untrackedChanges: false,
      },
      oldSha: /^-Subproject commit ([0-9a-f]+)/m.exec(raw)?.[1] ?? null,
      newSha: /^\+Subproject commit ([0-9a-f]+)/m.exec(raw)?.[1] ?? null,
    }
  }
  const parsed = new DiffParser().parse(raw)
  if (parsed.isBinary) {
    if (!imageTypes[extname(file.path).toLowerCase()]) return { kind: 'binary' }
    const image = (contents: Buffer, path: string): DiffImage => ({
      contents: contents.toString('base64'),
      bytes: contents.length,
      mediaType: imageTypes[extname(path).toLowerCase()] ?? 'application/octet-stream',
    })
    const previous =
      previousRef && file.status.kind !== Kind.New && file.status.kind !== Kind.Untracked
        ? image(
            (
              await git(['show', `${previousRef}:${oldPath(file)}`], repoPath, 'previousImage', {
                encoding: 'buffer',
              })
            ).stdout,
            oldPath(file)
          )
        : undefined
    const current =
      file.status.kind === Kind.Deleted
        ? undefined
        : image(
            currentRef
              ? (
                  await git(['show', `${currentRef}:${file.path}`], repoPath, 'currentImage', {
                    encoding: 'buffer',
                  })
                ).stdout
              : await readFile(resolve(repoPath, file.path)),
            file.path
          )
    return { kind: 'image', previous, current }
  }
  const endings = /(?:CRLF|CR|LF) will be replaced by (?:CRLF|CR|LF)/
    .exec(stderr.toString('utf8'))?.[0]
    .split(' will be replaced by ') as [LineEnding, LineEnding] | undefined
  return {
    kind:
      buffer.length >= MaxReasonableDiffSize ||
      parsed.hunks.some((h) => h.lines.some((l) => l.text.length > 5000))
        ? 'large'
        : 'text',
    text: parsed.contents,
    hunks: parsed.hunks,
    maxLineNumber: parsed.maxLineNumber,
    hasHiddenBidiChars: parsed.hasHiddenBidiChars,
    ...(endings ? { lineEndingsChange: { from: endings[0], to: endings[1] } } : {}),
  }
}

/** Fetch commit file metadata without depending on the history worker. */
export async function getCommittedFile(
  repoPath: string,
  sha: string,
  path: string
): Promise<CommittedFile> {
  validatePath(repoPath, path)
  const commit = await resolveCommit(repoPath, sha)
  const parent = await parentOrEmptyTree(repoPath, commit)
  const tokens = (
    await git(
      ['diff-tree', '--no-commit-id', '-r', '-M', '--name-status', '-z', parent, commit, '--'],
      repoPath,
      'committedFile'
    )
  ).stdout.split('\0')
  for (let i = 0; i < tokens.length - 1;) {
    const code = tokens[i++]
    const from = tokens[i++]
    const renamed = code.startsWith('R') || code.startsWith('C')
    const to = renamed ? tokens[i++] : from
    if (to !== path) continue
    if (renamed)
      return {
        path,
        status: {
          kind: code[0] === 'R' ? Kind.Renamed : Kind.Copied,
          oldPath: from,
          renameIncludesModifications: code.slice(1) !== '100',
        },
      }
    return {
      path,
      status: { kind: code === 'A' ? Kind.New : code === 'D' ? Kind.Deleted : Kind.Modified },
    }
  }
  throw new HandlerError('not-found', `File is not changed in commit: ${path}`)
}
