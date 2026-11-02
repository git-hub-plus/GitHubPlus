// Ported from GitHub Desktop (MIT): app/test/unit/git/log-test.ts
import { describe, expect, it } from 'vitest'
import { getCommitFiles, getCommits } from '../../../src/main/git/log'
import { AppFileStatusKind as Kind } from '../../../src/shared/models/status'
import { commit, file, repository, run } from './helpers'

describe('commit history', () => {
  it('converts raw epoch seconds and a negative timezone offset into identity data', async () => {
    const root = await repository()
    await run(root, ['commit', '--allow-empty', '--date=1234567890 -0330', '-m', 'dated'])
    expect((await getCommits(root, { limit: 1 }))[0].author).toEqual({
      name: 'Test',
      email: 'test@example.com',
      date: 1234567890000,
      tzOffset: -210,
    })
  })
  it('handles unborn history and rejects invalid explicit refs', async () => {
    const root = await repository()
    expect(await getCommits(root, { limit: 10 })).toEqual([])
    expect(await getCommits(root, { limit: 10, all: true })).toEqual([])
    await expect(getCommits(root, { ref: '--all', limit: 10 })).rejects.toThrow()
    await expect(getCommits(root, { limit: -1 })).rejects.toThrow()
  })
  it('loads identity dates, body, tags, pagination and literal path filters', async () => {
    const root = await repository()
    await file(root, 'HEAD')
    const first = await commit(root, 'first')
    await run(root, ['tag', 'release,one'])
    await run(root, ['tag', '-a', 'annotated', '-m', 'tag'])
    await file(root, 'other')
    const second = await commit(root, 'second\n\nbody line\n')
    await file(root, 'HEAD', 'third\n')
    const third = await commit(root, 'third')
    const all = await getCommits(root, { limit: 10 })
    expect(all.map((c) => c.sha)).toEqual([third, second, first])
    expect(all[0].parentShas).toEqual([second])
    expect(all[2].parentShas).toEqual([])
    expect(all[1].body).toBe('body line\n')
    expect([...all[2].tags].sort()).toEqual(['annotated', 'release,one'])
    expect(all[0].author).toMatchObject({ name: 'Test', email: 'test@example.com' })
    expect(all[0].author.date).toBeGreaterThan(1e12)
    expect((await getCommits(root, { limit: 1, skip: 1 }))[0].sha).toBe(second)
    const filtered = await getCommits(root, { limit: 10, path: 'HEAD' })
    expect(filtered.map((c) => c.sha)).toEqual([third, first])
    expect(filtered[0].parentShas).toEqual([second])
    expect(await getCommitFiles(root, first)).toMatchObject([
      { path: 'HEAD', status: { kind: Kind.New } },
    ])
  })
  it('includes other branches in topological order and diffs merges against the first parent', async () => {
    const root = await repository()
    await file(root, 'base')
    const base = await commit(root, 'base')
    await run(root, ['checkout', '-b', 'topic'])
    await file(root, 'topic')
    const topic = await commit(root, 'topic')
    await run(root, ['checkout', 'main'])
    await file(root, 'main')
    const main = await commit(root, 'main')
    expect((await getCommits(root, { limit: 10 })).some((c) => c.sha === topic)).toBe(false)
    const all = await getCommits(root, { limit: 10, all: true })
    expect(new Set(all.map((c) => c.sha))).toEqual(new Set([base, topic, main]))
    expect(all.at(-1)?.sha).toBe(base)
    await run(root, ['merge', '--no-ff', 'topic', '-m', 'merge'])
    const merge = (await getCommits(root, { limit: 1 }))[0]
    expect(merge.parentShas).toEqual([main, topic])
    expect(await getCommitFiles(root, merge.sha)).toMatchObject([
      { path: 'topic', status: { kind: Kind.New } },
    ])
  })
  it('detects committed renames with whitespace in paths', async () => {
    const root = await repository()
    await file(root, 'old name')
    await commit(root, 'base')
    await run(root, ['mv', 'old name', '새 이름'])
    const sha = await commit(root, 'rename')
    expect(await getCommitFiles(root, sha)).toMatchObject([
      {
        path: '새 이름',
        status: { kind: Kind.Renamed, oldPath: 'old name', renameIncludesModifications: false },
      },
    ])
  })
})
