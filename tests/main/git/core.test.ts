import { mkdtemp, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'

vi.mock('../../../src/main/log', () => ({
  log: { debug: vi.fn(), info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}))

import { git, GitError, registerGitAuthProvider } from '../../../src/main/git/core'
import { log } from '../../../src/main/log'

describe('git core auth providers', () => {
  const cleanups: Array<() => unknown> = []
  afterEach(async () => {
    while (cleanups.length) await cleanups.pop()!()
  })

  it('applies provider config but never exposes it in errors or logs', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'ghp-core-'))
    cleanups.push(() => rm(dir, { recursive: true, force: true }))
    const secret = 'http.extraHeader=AUTHORIZATION: basic c2VjcmV0LXRva2Vu'
    cleanups.push(registerGitAuthProvider(() => ({ configArgs: ['-c', secret] })))

    const shown = await git(['config', '--get', 'http.extraHeader'], dir, 'test', {
      successExitCodes: new Set([0, 1]),
    })
    expect(shown.stdout.trim()).toBe('AUTHORIZATION: basic c2VjcmV0LXRva2Vu')

    const failure = await git(['rev-parse', 'no-such-ref'], dir, 'test').catch((e) => e)
    expect(failure).toBeInstanceOf(GitError)
    expect((failure as GitError).message).not.toContain('c2VjcmV0')
    expect((failure as GitError).args).not.toContain(secret)
    const logged = JSON.stringify(vi.mocked(log.warn).mock.calls)
    expect(logged).not.toContain('c2VjcmV0')
  })
})
