import { mkdtemp, rm, readFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { exec } from 'dugite'
import { afterEach, beforeEach, expect, it, vi } from 'vitest'
import { getIdentity, setIdentity } from '../../../src/main/git/identity'

let directory: string
let repository: string
let globalConfig: string
beforeEach(async () => {
  directory = await mkdtemp(join(tmpdir(), 'ghp-identity-'))
  repository = join(directory, 'repo')
  globalConfig = join(directory, 'global.gitconfig')
  vi.stubEnv('GIT_CONFIG_GLOBAL', globalConfig)
  vi.stubEnv('GIT_CONFIG_NOSYSTEM', '1')
  const result = await exec(['init', repository], directory)
  expect(result.exitCode).toBe(0)
})
afterEach(async () => {
  vi.unstubAllEnvs()
  await rm(directory, { recursive: true, force: true })
})
it('reports missing and incomplete identity and sets repository identity', async () => {
  expect(await getIdentity(repository)).toEqual({ source: 'none' })
  await exec(['config', '--local', 'user.name', 'Only Name'], repository)
  expect(await getIdentity(repository)).toEqual({ name: 'Only Name', source: 'none' })
  expect(
    await setIdentity(repository, {
      name: ' Repo User ',
      email: ' repo@example.com ',
      scope: 'repository',
    })
  ).toEqual({ name: 'Repo User', email: 'repo@example.com', source: 'repository' })
  await expect(readFile(globalConfig)).rejects.toMatchObject({ code: 'ENOENT' })
})
it('writes only an isolated global file and respects local overrides', async () => {
  expect(
    await setIdentity(repository, {
      name: 'Global User',
      email: 'global@example.com',
      scope: 'global',
    })
  ).toEqual({ name: 'Global User', email: 'global@example.com', source: 'global' })
  expect(await readFile(globalConfig, 'utf8')).toContain('global@example.com')
  await exec(['config', '--local', 'user.name', 'Local Name'], repository)
  expect(await getIdentity(repository)).toEqual({
    name: 'Local Name',
    email: 'global@example.com',
    source: 'repository',
  })
  await setIdentity(repository, { name: 'New Global', email: 'new@example.com', scope: 'global' })
  expect(await getIdentity(repository)).toEqual({
    name: 'Local Name',
    email: 'new@example.com',
    source: 'repository',
  })
})
it('reads effective values from included local config', async () => {
  const config = join(directory, 'included.config')
  await exec(['config', '--file', config, 'user.name', 'Included'], directory)
  await exec(['config', '--file', config, 'user.email', 'included@example.com'], directory)
  await exec(['config', '--local', 'include.path', config], repository)
  expect(await getIdentity(repository)).toEqual({
    name: 'Included',
    email: 'included@example.com',
    source: 'repository',
  })
})
it.each([
  'invalid',
  'a@b',
  'a@@b.com',
  'a b@example.com',
  'x@example.com\nextra',
  'x@<example.com>',
])('rejects invalid email %s before writing', async (email) => {
  await expect(
    setIdentity(repository, { name: 'Test', email, scope: 'repository' })
  ).rejects.toMatchObject({ kind: 'invalid-argument' })
  expect((await getIdentity(repository)).source).toBe('none')
})
it('rejects empty names and unsupported scopes', async () => {
  await expect(
    setIdentity(repository, { name: ' ', email: 'test@example.com', scope: 'repository' })
  ).rejects.toMatchObject({ kind: 'invalid-argument' })
  await expect(
    setIdentity(repository, {
      name: 'Test',
      email: 'test@example.com',
      scope: 'system' as 'global',
    })
  ).rejects.toMatchObject({ kind: 'invalid-argument' })
})
