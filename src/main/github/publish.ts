import { HandlerError } from '@shared/errors'
import type { GitHubIpc } from '@shared/ipc/integrations'
import { git, withGitErrors } from '../git/core'
import { push } from '../git/push'
import type { ProgressCallback } from '../git/progress/from-process'
import { getRepository, updateRepository } from '../store/repositories'
import type { GitHubService } from './service'
import { isGitHubHttps } from './auth'

export interface PublishDependencies {
  getRepository: typeof getRepository
  updateRepository: typeof updateRepository
  cacheOrigin: (path: string, url: string) => void
  /** Tests can use a local bare remote while production requires GitHub HTTPS. */
  validateUrl?: (url: string) => boolean
}

export function createPublisher(
  service: Pick<GitHubService, 'api'>,
  dependencies: PublishDependencies
): (
  id: string,
  input: Parameters<GitHubIpc['github:publish']>[1],
  progress?: ProgressCallback
) => ReturnType<typeof updateRepository> {
  const active = new Set<string>()
  return async (id, input, progress) => {
    if (active.has(id)) throw new HandlerError('invalid-argument', '이미 게시 중인 저장소입니다')
    if (
      !/^[\w.-]+$/.test(input.name) ||
      input.name === '.' ||
      input.name === '..' ||
      typeof input.private !== 'boolean' ||
      !input.opId
    ) {
      throw new HandlerError('invalid-argument', '저장소 이름과 게시 옵션을 확인하세요')
    }
    active.add(id)
    try {
      return await withGitErrors(async () => {
        const repo = dependencies.getRepository(id)
        const remotes = (await git(['remote'], repo.path, 'publishRemotes')).stdout.split(/\r?\n/)
        if (remotes.includes('origin'))
          throw new HandlerError('invalid-argument', '이미 origin 원격이 있는 저장소입니다')
        const branch = (
          await git(['symbolic-ref', '--quiet', '--short', 'HEAD'], repo.path, 'publishBranch')
        ).stdout.trim()
        await git(['rev-parse', '--verify', 'HEAD'], repo.path, 'publishHead')
        const created = await service.api<{ clone_url: string }>(
          'https://api.github.com/user/repos',
          {
            method: 'POST',
            body: JSON.stringify({
              name: input.name,
              description: input.description,
              private: input.private,
            }),
          }
        )
        if (!(dependencies.validateUrl ?? isGitHubHttps)(created.clone_url))
          throw new HandlerError('network', 'GitHub 저장소 주소가 올바르지 않습니다')
        await git(['remote', 'add', 'origin', created.clone_url], repo.path, 'publishAddOrigin')
        dependencies.cacheOrigin(repo.path, created.clone_url)
        try {
          await push(repo.path, { remote: 'origin', branch, setUpstream: true }, progress)
        } catch {
          // The remote has been created; retain origin so a normal push can retry.
          await dependencies.updateRepository(id, { remoteUrl: created.clone_url })
          throw new HandlerError(
            'network',
            'GitHub 저장소를 만들었지만 push에 실패했습니다. origin으로 다시 push하세요'
          )
        }
        return dependencies.updateRepository(id, { remoteUrl: created.clone_url })
      })
    } finally {
      active.delete(id)
    }
  }
}
