import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, expect, it, vi } from 'vitest'
import { repository, run } from '../../git/helpers'

const storage = vi.hoisted(() => ({ directory: '' }))
vi.mock('electron', () => ({ app: { getPath: () => storage.directory } }))
import {
  addRepository,
  groupForRemote,
  listRepositories,
  registerHubUrlMatcher,
} from '../../../../src/main/store/repositories'
import { refreshHubGroups } from '../../../../src/main/hub/client/groups'

afterEach(async () => {
  if (storage.directory) await rm(storage.directory, { recursive: true, force: true })
})
it('reclassifies origin and secondary hub remotes when discovery changes', async () => {
  storage.directory = await mkdtemp(join(tmpdir(), 'ghp-hub-groups-'))
  const primary = await repository()
  const secondary = await repository()
  const known = new Set<string>()
  const matches = (url: string) => {
    try {
      return known.has(new URL(url).origin)
    } catch {
      return false
    }
  }
  registerHubUrlMatcher(matches)
  await run(primary, ['remote', 'add', 'origin', 'http://192.168.0.2:8765/a.git'])
  await run(secondary, ['remote', 'add', 'origin', 'https://github.com/org/a.git'])
  await run(secondary, ['remote', 'add', 'hub', 'http://192.168.0.2:8765/b.git'])
  await addRepository(primary)
  await addRepository(secondary)
  expect(groupForRemote('http://192.168.0.2:8765/a.git')).toBe('local')
  known.add('http://192.168.0.2:8765')
  await refreshHubGroups(matches)
  expect(listRepositories().map((repo) => repo.group)).toEqual(['hub', 'hub'])
  known.clear()
  await refreshHubGroups(matches)
  expect(listRepositories().map((repo) => repo.group)).toEqual(['local', 'github'])
})
