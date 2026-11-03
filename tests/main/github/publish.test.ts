import { mkdir, mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { exec } from 'dugite'
import { afterEach, describe, expect, it, vi } from 'vitest'
import type { RepositoryInfo } from '../../../src/shared/models/app'
import { createPublisher } from '../../../src/main/github/publish'

vi.mock('../../../src/main/log', () => ({
  log: { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}))

describe('GitHub publish', () => {
  const directories: string[] = []
  afterEach(async () => {
    await Promise.all(
      directories.splice(0).map((path) => rm(path, { recursive: true, force: true }))
    )
  })

  async function setup() {
    const directory = await mkdtemp(join(tmpdir(), 'ghp-github-publish-'))
    directories.push(directory)
    const path = join(directory, 'working')
    const remote = join(directory, 'remote.git')
    await mkdir(path)
    await mkdir(remote)
    const run = async (args: string[], cwd = path) => {
      const result = await exec(args, cwd)
      expect(result.exitCode, result.stderr).toBe(0)
      return result.stdout.trim()
    }
    await run(['init', '-b', 'main'])
    await run([
      '-c',
      'user.name=Test',
      '-c',
      'user.email=test@example.com',
      'commit',
      '--allow-empty',
      '-m',
      'initial',
    ])
    await run(['init', '--bare'], remote)
    const repo: RepositoryInfo = {
      id: 'local-id',
      name: 'working',
      path,
      group: 'local',
      pinned: false,
      addedAt: 1,
      available: true,
    }
    const api = vi.fn(async (_url: string, _init?: RequestInit) => ({ clone_url: remote }))
    const cacheOrigin = vi.fn()
    const updateRepository = vi.fn(async (_id: string, patch: { remoteUrl?: string }) => ({
      ...repo,
      remoteUrl: patch.remoteUrl,
      group: 'github' as const,
    }))
    const publish = createPublisher(
      { api: async <T>(url: string, init?: RequestInit) => (await api(url, init)) as T },
      {
        getRepository: () => repo,
        updateRepository,
        cacheOrigin,
        validateUrl: (url) => url === remote,
      }
    )
    return { directory, path, remote, repo, run, api, cacheOrigin, updateRepository, publish }
  }

  it('creates the API repository, adds origin, pushes with upstream, and updates the group', async () => {
    const { publish, api, remote, path, run, cacheOrigin, updateRepository } = await setup()
    const progress = vi.fn()
    const input = {
      name: 'published',
      description: 'description',
      private: true,
      opId: 'publish-op',
    }
    const updated = await publish('local-id', input, progress)
    expect(api).toHaveBeenCalledWith('https://api.github.com/user/repos', {
      method: 'POST',
      body: JSON.stringify({ name: 'published', description: 'description', private: true }),
    })
    expect(await run(['config', 'remote.origin.url'])).toBe(remote)
    expect(await run(['config', 'branch.main.remote'])).toBe('origin')
    expect(await run(['config', 'branch.main.merge'])).toBe('refs/heads/main')
    expect(await run(['rev-parse', 'refs/heads/main'], remote)).toBe(
      await run(['rev-parse', 'HEAD'])
    )
    expect(cacheOrigin).toHaveBeenCalledWith(path, remote)
    expect(updateRepository).toHaveBeenCalledWith('local-id', { remoteUrl: remote })
    expect(updated).toMatchObject({ group: 'github', remoteUrl: remote })
    expect(progress).toHaveBeenCalled()
  })

  it('rejects an existing origin before creating a remote API repository', async () => {
    const { publish, api, run, remote, updateRepository } = await setup()
    await run(['remote', 'add', 'origin', remote])
    await expect(
      publish('local-id', { name: 'published', private: false, opId: 'publish-op' })
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
    expect(api).not.toHaveBeenCalled()
    expect(updateRepository).not.toHaveBeenCalled()
  })

  it('retains origin and updates repository information when the first push fails', async () => {
    const { publish, remote, run, updateRepository } = await setup()
    // Refuse branch creation to exercise an actual failed push to the local bare remote.
    await run(['config', 'receive.denyCurrentBranch', 'refuse'], remote)
    await run(['config', 'core.bare', 'false'], remote)
    await run(['symbolic-ref', 'HEAD', 'refs/heads/main'], remote)
    await expect(
      publish('local-id', { name: 'published', private: false, opId: 'publish-op' })
    ).rejects.toMatchObject({ kind: 'network' })
    expect(await run(['config', 'remote.origin.url'])).toBe(remote)
    expect(updateRepository).toHaveBeenCalledWith('local-id', { remoteUrl: remote })
  })

  it('rejects malformed repository names before making an API call', async () => {
    const { publish, api } = await setup()
    await expect(
      publish('local-id', { name: '../bad', private: false, opId: 'publish-op' })
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
    expect(api).not.toHaveBeenCalled()
  })
})
