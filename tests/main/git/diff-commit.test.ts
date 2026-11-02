// Ported from GitHub Desktop (MIT): app/test/unit/git/diff-test.ts,
// app/test/unit/git/commit-test.ts and app/test/unit/patch-formatter-test.ts
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { exec } from 'dugite'
import { mkdir, mkdtemp, readFile, rename, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { AppFileStatusKind as Kind, type WorkingFile } from '@shared/models/status'
import { DiffLineType, type DiffSelectionData, type FileDiff } from '@shared/models/diff'
import { selectAll, selectNone } from '@shared/models/diff-selection'
import { createCommit } from '../../../src/main/git/commit'
import { discardLines } from '../../../src/main/git/apply'
import { getCommitDiff, getCommittedFile, getWorkingDiff } from '../../../src/main/git/diff'
import type { GitOptions } from '../../../src/main/git/core'

// Keep identity on each test command, including commands issued by production
// functions, without relying on or changing any user's Git configuration.
vi.mock('../../../src/main/git/core', async (importOriginal) => {
  const actual = await importOriginal<typeof import('../../../src/main/git/core')>()
  return {
    ...actual,
    git: (
      args: string[],
      path: string,
      name: string,
      options?: GitOptions & { encoding?: 'utf8' | 'buffer' }
    ) => {
      const identified = ['-c', 'user.name=Test', '-c', 'user.email=test@example.com', ...args]
      return options?.encoding === 'buffer'
        ? actual.git(identified, path, name, { ...options, encoding: 'buffer' })
        : actual.git(identified, path, name, { ...options, encoding: 'utf8' })
    },
  }
})

let repo: string
async function git(...args: string[]) {
  const result = await exec(
    ['-c', 'user.name=Test', '-c', 'user.email=test@example.com', ...args],
    repo
  )
  if (result.exitCode !== 0) throw new Error(result.stderr)
  return result.stdout.trim()
}
function file(
  path: string,
  kind: Kind.Modified | Kind.Untracked | Kind.New | Kind.Deleted = Kind.Modified
): WorkingFile {
  return { path, status: { kind } }
}
function lines(diff: FileDiff, texts: string[]): DiffSelectionData {
  if (diff.kind !== 'text' && diff.kind !== 'large') throw new Error('Expected text diff')
  const changed = diff.hunks
    .flatMap((h) => h.lines)
    .filter((l) => l.type === DiffLineType.Add || l.type === DiffLineType.Delete)
  return {
    defaultSelectionType: 'none',
    divergingLines: changed.filter((l) => texts.includes(l.text)).map((l) => l.originalLineNumber!),
    selectableLines: changed.map((l) => l.originalLineNumber!),
  }
}
async function commit(
  files: WorkingFile[],
  selections: DiffSelectionData[] = files.map(() => selectAll()),
  amend = false,
  summary = 'selected'
) {
  return createCommit(
    repo,
    {
      summary,
      description: 'body',
      amend,
      files: files.map((f, i) => ({ path: f.path, selection: selections[i] })),
    },
    files
  )
}
beforeEach(async () => {
  repo = await mkdtemp(join(tmpdir(), 'ghp-g1-'))
  await git('init', '--initial-branch=main')
  await git('config', 'core.autocrlf', 'false')
  await writeFile(join(repo, 'file.txt'), 'one\ntwo\nthree\nfour\n')
  await writeFile(join(repo, 'other.txt'), 'original\n')
  await git('add', '.')
  await git('commit', '-m', 'initial')
})
afterEach(async () => {
  await rm(repo, { recursive: true, force: true })
})

describe('selected commits', () => {
  it('rejects an implicit deletion of a file omitted from the input', async () => {
    const before = await git('rev-parse', 'HEAD')
    await rm(join(repo, 'other.txt'))
    await mkdir(join(repo, 'other.txt'))
    await writeFile(join(repo, 'other.txt/nested.txt'), 'nested\n')
    await expect(commit([file('other.txt/nested.txt', Kind.Untracked)])).rejects.toThrow(
      'unlisted file'
    )
    expect(await git('rev-parse', 'HEAD')).toBe(before)
    expect(await git('show', ':other.txt')).toBe('original')
  })
  it('commits selected replacement lines and preserves unstaged and unrelated staged edits', async () => {
    await writeFile(join(repo, 'file.txt'), 'ONE\ntwo\nTHREE\nfour\n')
    await writeFile(join(repo, 'other.txt'), 'staged elsewhere\n')
    await git('add', 'other.txt')
    const otherIndex = await git('rev-parse', ':other.txt')
    // A staged change in the selected file must not determine the selection.
    await git('add', 'file.txt')
    const f = file('file.txt')
    const diff = await getWorkingDiff(repo, f)
    const sha = await commit([f], [lines(diff, ['-one', '+ONE'])])
    expect(await git('show', `${sha}:file.txt`)).toBe('ONE\ntwo\nthree\nfour')
    expect(await readFile(join(repo, 'file.txt'), 'utf8')).toBe('ONE\ntwo\nTHREE\nfour\n')
    expect(await git('show', `${sha}:other.txt`)).toBe('original')
    expect(await git('rev-parse', ':other.txt')).toBe(otherIndex)
    expect(await git('show', ':file.txt')).toBe('ONE\ntwo\nthree\nfour')
  })
  it('commits untracked, deleted and renamed files, including a recreated rename source', async () => {
    await writeFile(join(repo, 'new.txt'), 'new\n')
    await rm(join(repo, 'other.txt'))
    await rename(join(repo, 'file.txt'), join(repo, 'renamed.txt'))
    await git('add', '-A')
    await writeFile(join(repo, 'file.txt'), 'keep untracked source\n')
    const renamed: WorkingFile = {
      path: 'renamed.txt',
      status: { kind: Kind.Renamed, oldPath: 'file.txt', renameIncludesModifications: false },
    }
    const sha = await commit([
      file('new.txt', Kind.Untracked),
      file('other.txt', Kind.Deleted),
      renamed,
    ])
    expect(await git('ls-tree', '--name-only', sha)).toBe('new.txt\nrenamed.txt')
    expect(await readFile(join(repo, 'file.txt'), 'utf8')).toBe('keep untracked source\n')
    const metadata = await getCommittedFile(repo, sha, 'renamed.txt')
    expect(metadata.status.kind).toBe(Kind.Renamed)
    expect((await getCommitDiff(repo, sha, metadata)).kind).toBe('text')
  })
  it('amends message and contents and supports a message-only amend', async () => {
    const parent = await git('rev-parse', 'HEAD')
    await writeFile(join(repo, 'file.txt'), 'changed\n')
    await commit([file('file.txt')])
    await writeFile(join(repo, 'other.txt'), 'amended\n')
    const sha = await commit([file('other.txt')], undefined, true, 'amended summary')
    expect(await git('rev-parse', `${sha}^`)).toBe(parent)
    expect(await git('show', `${sha}:file.txt`)).toBe('changed')
    expect(await git('show', `${sha}:other.txt`)).toBe('amended')
    expect(await git('log', '-1', '--format=%B')).toBe('amended summary\n\nbody')
    await commit([], [], true, 'message only')
    expect(await git('log', '-1', '--format=%s')).toBe('message only')
  })
  it('partially commits a new file without trailing newline', async () => {
    await writeFile(join(repo, 'new.txt'), 'first\nsecond')
    const f = file('new.txt', Kind.Untracked)
    const sha = await commit([f], [lines(await getWorkingDiff(repo, f), ['+second'])])
    const result = await exec(['show', `${sha}:new.txt`], repo)
    expect(result.stdout).toBe('second')
    expect(await readFile(join(repo, 'new.txt'), 'utf8')).toBe('first\nsecond')
  })
  it('partially commits renamed contents relative to HEAD, including staged modifications', async () => {
    await rename(join(repo, 'file.txt'), join(repo, 'new name.txt'))
    await git('add', '-A')
    await writeFile(join(repo, 'new name.txt'), 'ONE\ntwo\nTHREE\nfour\n')
    await git('add', 'new name.txt')
    const f: WorkingFile = {
      path: 'new name.txt',
      status: { kind: Kind.Renamed, oldPath: 'file.txt', renameIncludesModifications: true },
    }
    const sha = await commit([f], [lines(await getWorkingDiff(repo, f), ['-one', '+ONE'])])
    expect(await git('show', `${sha}:new name.txt`)).toBe('ONE\ntwo\nthree\nfour')
    expect(await git('ls-tree', '--name-only', sha)).not.toContain('file.txt')
  })
  it('creates an initial commit and shows its diff', async () => {
    const initial = await mkdtemp(join(tmpdir(), 'ghp-g1-initial-'))
    const previous = repo
    try {
      repo = initial
      await git('init')
      await writeFile(join(repo, 'initial.txt'), 'hello\n')
      const f = file('initial.txt', Kind.Untracked)
      const sha = await commit([f])
      const diff = await getCommitDiff(repo, sha, await getCommittedFile(repo, sha, f.path))
      expect(diff.kind).toBe('text')
      if (diff.kind === 'text') expect(diff.text).toContain('+hello')
    } finally {
      repo = previous
      await rm(initial, { recursive: true, force: true })
    }
  })
  it('leaves the index and HEAD unchanged when a partial binary commit fails', async () => {
    await writeFile(join(repo, 'binary.dat'), Buffer.from([0, 1, 2]))
    const before = await git('rev-parse', 'HEAD')
    const index = await readFile(join(repo, '.git/index'))
    await expect(
      commit(
        [file('binary.dat', Kind.Untracked)],
        [{ defaultSelectionType: 'none', divergingLines: [1] }]
      )
    ).rejects.toThrow('Cannot select lines')
    expect(await git('rev-parse', 'HEAD')).toBe(before)
    expect(await readFile(join(repo, '.git/index'))).toEqual(index)
  })
})

describe('line discard and diff classification', () => {
  it('identifies committed submodules by gitlink mode, not ordinary matching text', async () => {
    const sha = await git('rev-parse', 'HEAD')
    await git('update-index', '--add', '--cacheinfo', '160000', sha, 'sub')
    await git('commit', '-m', 'add submodule')
    const tip = await git('rev-parse', 'HEAD')
    const diff = await getCommitDiff(repo, tip, await getCommittedFile(repo, tip, 'sub'))
    expect(diff.kind).toBe('submodule')
    if (diff.kind === 'submodule') {
      expect(diff.newSha).toBe(sha)
      expect(diff.oldSha).toBeNull()
    }
    await writeFile(join(repo, 'ordinary.txt'), 'Subproject commit abc123\n')
    expect((await getWorkingDiff(repo, file('ordinary.txt', Kind.Untracked))).kind).toBe('text')
  })
  it('discards selected replacement lines and keeps index untouched', async () => {
    await writeFile(join(repo, 'file.txt'), 'ONE\ntwo\nTHREE\nfour\n')
    await git('add', 'file.txt')
    const index = await git('rev-parse', ':file.txt')
    const f = file('file.txt')
    await discardLines(repo, f, lines(await getWorkingDiff(repo, f), ['-one', '+ONE']))
    expect(await readFile(join(repo, f.path), 'utf8')).toBe('one\ntwo\nTHREE\nfour\n')
    expect(await git('rev-parse', ':file.txt')).toBe(index)
    await discardLines(repo, f, selectNone())
    expect(await readFile(join(repo, f.path), 'utf8')).toBe('one\ntwo\nTHREE\nfour\n')
  })
  it('discards selected additions from untracked files', async () => {
    await writeFile(join(repo, 'new.txt'), 'first\nsecond\n')
    const f = file('new.txt', Kind.Untracked)
    await discardLines(repo, f, lines(await getWorkingDiff(repo, f), ['+first']))
    expect(await readFile(join(repo, f.path), 'utf8')).toBe('second\n')
  })
  it('restores selected deleted lines without restoring the whole deleted file', async () => {
    await rm(join(repo, 'file.txt'))
    const f = file('file.txt', Kind.Deleted)
    await discardLines(repo, f, lines(await getWorkingDiff(repo, f), ['-two']))
    expect(await readFile(join(repo, f.path), 'utf8')).toBe('two\n')
  })
  it('classifies binary, base64 images, image deletion and large lines', async () => {
    const binary = Buffer.from([0, 1, 2, 3])
    await writeFile(join(repo, 'binary.dat'), binary)
    await writeFile(join(repo, 'IMAGE.PNG'), binary)
    expect((await getWorkingDiff(repo, file('binary.dat', Kind.Untracked))).kind).toBe('binary')
    const image = await getWorkingDiff(repo, file('IMAGE.PNG', Kind.Untracked))
    expect(image).toEqual({
      kind: 'image',
      previous: undefined,
      current: { contents: binary.toString('base64'), bytes: 4, mediaType: 'image/png' },
    })
    const sha = await commit([file('IMAGE.PNG', Kind.Untracked)])
    expect(await getCommitDiff(repo, sha, await getCommittedFile(repo, sha, 'IMAGE.PNG'))).toEqual(
      image
    )
    await rm(join(repo, 'IMAGE.PNG'))
    const deleted = await getWorkingDiff(repo, file('IMAGE.PNG', Kind.Deleted))
    expect(deleted.kind).toBe('image')
    if (deleted.kind === 'image') {
      expect(deleted.previous?.contents).toBe(binary.toString('base64'))
      expect(deleted.current).toBeUndefined()
    }
    await writeFile(join(repo, 'long.txt'), 'a'.repeat(5001))
    expect((await getWorkingDiff(repo, file('long.txt', Kind.Untracked))).kind).toBe('large')
  })
})
