import { mkdtemp, mkdir, readFile, rm, symlink, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

vi.mock('../../../src/main/ipc', () => ({ handle: vi.fn() }))
vi.mock('../../../src/main/store/repositories', () => ({ getRepository: vi.fn() }))
import { copyIntoRepository } from '../../../src/main/files/register'

let directory: string
let root: string
let source: string
beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), 'ghp-copy-'))
  root = join(directory, 'repo')
  source = join(directory, 'source')
  await mkdir(root)
  await mkdir(source)
})
afterEach(async () => {
  await rm(directory, { recursive: true, force: true })
})

describe('copy into working tree', () => {
  it('copies recursively, excludes .git and preserves existing files', async () => {
    await mkdir(join(source, '.git'))
    await writeFile(join(source, '.git', 'config'), 'secret')
    await mkdir(join(source, 'nested'))
    await writeFile(join(source, 'nested', 'new.txt'), 'new')
    await writeFile(join(source, 'old.txt'), 'replacement')
    await mkdir(join(root, 'source'))
    await writeFile(join(root, 'source', 'old.txt'), 'keep')
    expect(await copyIntoRepository(root, { sources: [source], targetDirectory: '' })).toEqual({
      copied: ['source/nested/new.txt'],
      skipped: ['source/old.txt'],
    })
    expect(await readFile(join(root, 'source', 'old.txt'), 'utf8')).toBe('keep')
    await expect(readFile(join(root, 'source', '.git', 'config'))).rejects.toMatchObject({
      code: 'ENOENT',
    })
  })
  it.each(['../escape', '.git', 'nested/../../escape', 'folder/.GIT'])(
    'rejects target %s',
    async (targetDirectory) => {
      await writeFile(join(source, 'a.txt'), 'a')
      await expect(
        copyIntoRepository(root, { sources: [join(source, 'a.txt')], targetDirectory })
      ).rejects.toMatchObject({ kind: 'invalid-argument' })
    }
  )
  it('rejects destination junctions, including links outside the root', async () => {
    await symlink(source, join(root, 'link'), 'junction')
    await writeFile(join(source, 'a.txt'), 'a')
    await expect(
      copyIntoRepository(root, { sources: [join(source, 'a.txt')], targetDirectory: 'link' })
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
  })
  it('skips source links and refuses a recursive copy into itself', async () => {
    await symlink(source, join(directory, 'source-link'), 'junction')
    expect(
      await copyIntoRepository(root, {
        sources: [join(directory, 'source-link')],
        targetDirectory: '',
      })
    ).toEqual({ copied: [], skipped: ['source-link'] })
    await expect(
      copyIntoRepository(root, { sources: [root], targetDirectory: 'nested' })
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
  })
  it('skips an existing destination junction instead of writing through it', async () => {
    const folder = join(directory, 'folder')
    await mkdir(folder)
    await writeFile(join(folder, 'a.txt'), 'a')
    await symlink(source, join(root, 'folder'), 'junction')
    expect(await copyIntoRepository(root, { sources: [folder], targetDirectory: '' })).toEqual({
      copied: [],
      skipped: ['folder'],
    })
    await expect(readFile(join(source, 'a.txt'))).rejects.toMatchObject({ code: 'ENOENT' })
  })
})
