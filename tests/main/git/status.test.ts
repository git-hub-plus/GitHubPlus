// Ported from GitHub Desktop (MIT): app/test/unit/git/status-test.ts
import { rm, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'
import {
  AppFileStatusKind as Kind,
  UnmergedEntrySummary as Conflict,
} from '../../../src/shared/models/status'
import { getStatus } from '../../../src/main/git/status'
import { getAheadBehind } from '../../../src/main/git/rev-list'
import { commit, file, repository, run } from './helpers'

describe('working directory status', () => {
  it('reports unborn and detached HEAD without inventing a branch', async () => {
    const root = await repository()
    expect(await getStatus(root)).toMatchObject({
      headSha: undefined,
      ahead: 0,
      behind: 0,
      files: [],
      stashCount: 0,
    })
    await file(root, 'initial')
    const sha = await commit(root, 'initial')
    await run(root, ['checkout', '--detach', sha])
    expect(await getStatus(root)).toMatchObject({ currentBranch: undefined, headSha: sha })
  })
  it('reports added, modified, deleted, renamed and Unicode untracked files', async () => {
    const root = await repository()
    for (const path of ['modified', 'deleted', 'old']) await file(root, path)
    await commit(root, 'base')
    await file(root, 'modified', 'changed\n')
    await rm(join(root, 'deleted'))
    await run(root, ['mv', 'old', 'renamed'])
    await file(root, 'new', 'distinct added content\n')
    await run(root, ['add', 'new'])
    await file(root, '한 글.txt')
    const status = await getStatus(root)
    expect(status.currentBranch).toBe('main')
    expect(Object.fromEntries(status.files.map((f) => [f.path, f.status.kind]))).toEqual({
      modified: Kind.Modified,
      deleted: Kind.Deleted,
      renamed: Kind.Renamed,
      new: Kind.New,
      '한 글.txt': Kind.Untracked,
    })
    expect(status.files.find((f) => f.path === 'renamed')?.status).toMatchObject({
      oldPath: 'old',
      renameIncludesModifications: false,
    })
  })
  it('reports ahead/behind against a configured upstream and stash count', async () => {
    const root = await repository()
    await file(root, 'initial')
    await commit(root, 'base')
    await run(root, ['branch', 'upstream'])
    await run(root, ['branch', '--set-upstream-to=upstream', 'main'])
    await file(root, 'local')
    await commit(root, 'local')
    await run(root, ['checkout', 'upstream'])
    await file(root, 'remote')
    await commit(root, 'remote')
    await run(root, ['checkout', 'main'])
    await file(root, 'initial', 'stash me\n')
    await run(root, ['stash', 'push'])
    expect(await getStatus(root)).toMatchObject({
      upstream: 'upstream',
      ahead: 1,
      behind: 1,
      stashCount: 1,
    })
    expect(await getAheadBehind(root, 'main...upstream')).toEqual({ ahead: 1, behind: 1 })
    await run(root, ['branch', '-D', 'upstream'])
    expect(await getStatus(root)).toMatchObject({ ahead: 0, behind: 0 })
  })
  it('reports merge conflicts, text marker counts, binary and deleted conflicts', async () => {
    const root = await repository()
    await file(root, 'text')
    await file(root, 'binary', 'base\0data')
    await file(root, 'deleted')
    await commit(root, 'base')
    await run(root, ['checkout', '-b', 'other'])
    await file(root, 'text', 'theirs\n')
    await file(root, 'binary', 'theirs\0data')
    await file(root, 'deleted', 'theirs\n')
    await commit(root, 'theirs')
    await run(root, ['checkout', 'main'])
    await file(root, 'text', 'ours\n')
    await file(root, 'binary', 'ours\0data')
    await rm(join(root, 'deleted'))
    await commit(root, 'ours')
    await run(root, ['merge', 'other'], [1])
    const status = await getStatus(root)
    expect(status.inProgress?.kind).toBe('merge')
    expect(status.files.find((f) => f.path === 'text')?.status).toMatchObject({
      kind: Kind.Conflicted,
      action: Conflict.BothModified,
      conflictMarkerCount: 1,
    })
    expect(status.files.find((f) => f.path === 'binary')?.status).toMatchObject({
      kind: Kind.Conflicted,
    })
    expect(status.files.find((f) => f.path === 'binary')?.status).not.toHaveProperty(
      'conflictMarkerCount'
    )
    expect(status.files.find((f) => f.path === 'deleted')?.status).toMatchObject({
      action: Conflict.DeletedByUs,
    })
    await writeFile(join(root, 'text'), 'resolved\n')
    expect((await getStatus(root)).files.find((f) => f.path === 'text')?.status).toMatchObject({
      conflictMarkerCount: 0,
    })
  })
  it('recognizes rebase, cherry-pick and revert operation state', async () => {
    const root = await repository()
    await file(root, 'text')
    const base = await commit(root, 'base')
    await file(root, '.git/rebase-merge/head-name', 'refs/heads/topic\n')
    await file(root, '.git/rebase-merge/onto', base)
    await file(root, '.git/rebase-merge/msgnum', '2')
    await file(root, '.git/rebase-merge/end', '3')
    expect((await getStatus(root)).inProgress).toEqual({
      kind: 'rebase',
      targetBranch: 'topic',
      baseBranch: base,
      step: 2,
      totalSteps: 3,
    })
    await rm(join(root, '.git/rebase-merge'), { recursive: true })
    await file(root, '.git/CHERRY_PICK_HEAD', base)
    expect((await getStatus(root)).inProgress).toEqual({
      kind: 'cherry-pick',
      step: 1,
      totalSteps: 1,
    })
    await rm(join(root, '.git/CHERRY_PICK_HEAD'))
    await file(root, '.git/REVERT_HEAD', base)
    expect((await getStatus(root)).inProgress).toEqual({ kind: 'revert' })
  })
})
