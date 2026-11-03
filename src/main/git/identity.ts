import type { GitIdentity } from '@shared/ipc/git-advanced'
import { HandlerError } from '@shared/errors'
import { git } from './core'

async function readValue(path: string, key: string) {
  const result = await git(
    ['config', '--null', '--show-scope', '--show-origin', '--get', key],
    path,
    'getIdentity',
    { successExitCodes: new Set([0, 1]) }
  )
  if (result.exitCode === 1) return undefined
  const [scope, , value] = result.stdout.split('\0')
  return { value: value?.trim(), local: scope === 'local' || scope === 'worktree' }
}

/** Read each effective value independently, including config includes/overrides. */
export async function getIdentity(path: string): Promise<GitIdentity> {
  const [name, email] = await Promise.all([
    readValue(path, 'user.name'),
    readValue(path, 'user.email'),
  ])
  return {
    name: name?.value,
    email: email?.value,
    source:
      !name?.value || !email?.value ? 'none' : name.local || email.local ? 'repository' : 'global',
  }
}

export async function setIdentity(
  path: string,
  input: { name: string; email: string; scope: 'repository' | 'global' }
): Promise<GitIdentity> {
  if (
    !input ||
    typeof input.name !== 'string' ||
    typeof input.email !== 'string' ||
    !input.name.trim() ||
    /[\r\n\0]/.test(input.name) ||
    /[\r\n\0]/.test(input.email) ||
    !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(input.email.trim()) ||
    (input.scope !== 'repository' && input.scope !== 'global')
  )
    throw new HandlerError('invalid-argument', 'Invalid Git name, email, or scope')
  const scope = input.scope === 'global' ? '--global' : '--local'
  await git(['config', scope, '--replace-all', 'user.name', input.name.trim()], path, 'setIdentity')
  await git(
    ['config', scope, '--replace-all', 'user.email', input.email.trim()],
    path,
    'setIdentity'
  )
  return getIdentity(path)
}
