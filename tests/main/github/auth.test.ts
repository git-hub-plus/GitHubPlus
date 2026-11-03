import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('../../../src/main/log', () => ({
  log: { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}))

import { createGitHubAuthProvider } from '../../../src/main/github/auth'
import { git, registerGitAuthProvider } from '../../../src/main/git/core'
import { log } from '../../../src/main/log'

describe('GitHub git authentication', () => {
  const cleanups: Array<() => unknown> = []
  afterEach(async () => {
    while (cleanups.length) await cleanups.pop()!()
    vi.clearAllMocks()
  })

  const token = 'private-oauth-token'
  const encoded = Buffer.from(`x-access-token:${token}`).toString('base64')
  const origin = 'https://github.com/octocat/private.git'

  it.each(['fetch', 'pull', 'push', 'ls-remote'])(
    'adds a scoped header for %s against the cached GitHub origin',
    (command) => {
      const provider = createGitHubAuthProvider(
        () => token,
        () => origin
      )
      expect(provider([command, 'origin'], '/repo')?.configArgs).toEqual([
        '-c',
        `http.https://github.com/.extraheader=AUTHORIZATION: basic ${encoded}`,
        '-c',
        'credential.helper=',
      ])
    }
  )

  it('uses the explicit clone URL without an existing repository cache', () => {
    const provider = createGitHubAuthProvider(
      () => token,
      () => undefined
    )
    expect(
      provider(['clone', '--progress', '--', origin, '/target'], '/parent')?.configArgs
    ).toContain(`http.https://github.com/.extraheader=AUTHORIZATION: basic ${encoded}`)
  })

  it.each([
    ['status'],
    ['config', 'remote.origin.url'],
    ['clone', 'https://git.example.test/team/repo.git', '/target'],
    ['fetch', 'https://github.com.evil.test/repo.git'],
    ['push', 'http://github.com/octocat/private.git'],
    ['ls-remote', 'git@github.com:octocat/private.git'],
    ['fetch', 'https://github.com@evil.test/repo.git'],
  ])('does not provide credentials to unrelated command %j', (...args) => {
    const provider = createGitHubAuthProvider(
      () => token,
      () => origin
    )
    expect(provider(args, '/repo')).toBeUndefined()
  })

  it('does not provide credentials without a token or a known GitHub origin', () => {
    expect(
      createGitHubAuthProvider(
        () => undefined,
        () => origin
      )(['push'], '/repo')
    ).toBeUndefined()
    expect(
      createGitHubAuthProvider(
        () => token,
        () => undefined
      )(['push'], '/repo')
    ).toBeUndefined()
  })

  it('keeps the injected token and encoded header out of git errors and logs', async () => {
    const path = await mkdtemp(join(tmpdir(), 'ghp-github-auth-'))
    cleanups.push(() => rm(path, { recursive: true, force: true }))
    const provider = createGitHubAuthProvider(
      () => token,
      () => origin
    )
    cleanups.push(registerGitAuthProvider(provider))
    // An invalid option fails before contacting a remote, but still runs with provider configuration.
    const failure = await git(['fetch', '--not-a-real-option'], path, 'githubAuthTest').catch(
      (error: unknown) => error
    )
    expect(failure).toBeInstanceOf(Error)
    const shown = `${String(failure)} ${JSON.stringify(failure)} ${JSON.stringify(vi.mocked(log.warn).mock.calls)}`
    expect(shown).not.toContain(token)
    expect(shown).not.toContain(encoded)
    expect(shown).not.toContain('AUTHORIZATION')
  })
})
