import { HandlerError } from '@shared/errors'
import { git, withGitErrors } from '../../git/core'
import { getRemotes } from '../../git/remote'
import { push } from '../../git/push'
import type { ProgressCallback } from '../../git/progress/from-process'
import { HubApi } from './api'

export async function publishRepository(
  path: string,
  input: { hubUrl: string; name: string; description?: string },
  progress?: ProgressCallback,
  api = new HubApi()
): Promise<string> {
  return withGitErrors(async () => {
    // Check local prerequisites before creating anything on the server.
    const branch = (
      await git(['symbolic-ref', '--quiet', '--short', 'HEAD'], path, 'hubPublishBranch')
    ).stdout.trim()
    await git(['rev-parse', '--verify', 'HEAD'], path, 'hubPublishHead')
    const remotes = await getRemotes(path)
    const remote = remotes.some((r) => r.name === 'origin') ? 'hub' : 'origin'
    if (remotes.some((r) => r.name === remote))
      throw new HandlerError('invalid-argument', 'hub 원격이 이미 있습니다.')
    const created = await api.create(input.hubUrl, input.name, input.description)
    await git(['remote', 'add', '--', remote, created.url], path, 'hubPublishRemote')
    // Keep the remote after a failed push so the user can retry without creating another repository.
    await push(path, { remote, branch, setUpstream: true }, progress)
    return created.url
  })
}
