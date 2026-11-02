// Ported from GitHub Desktop (MIT): app/src/lib/git/branch.ts
import { HandlerError } from '@shared/errors'
import { git, GitError, DugiteError } from './core'
import { getBranches } from './for-each-ref'
import { checkoutBranch } from './checkout'
import { getConfigValue } from './config'

export async function createBranch(
  path: string,
  input: { name: string; startPoint?: string; checkout?: boolean }
): Promise<void> {
  await git(
    ['branch', '--no-track', '--', input.name, ...(input.startPoint ? [input.startPoint] : [])],
    path,
    'createBranch'
  )
  if (input.checkout) await checkoutBranch(path, input.name)
}

export async function renameBranch(path: string, oldName: string, newName: string): Promise<void> {
  try {
    await git(['branch', '-m', '--', oldName, newName], path, 'renameBranch')
  } catch (error) {
    if (
      error instanceof GitError &&
      error.result.gitError === DugiteError.BranchAlreadyExists &&
      oldName.toLowerCase() === newName.toLowerCase() &&
      !(await getBranches(path)).some(
        (branch) => branch.type === 'local' && branch.name === newName
      )
    ) {
      await git(['branch', '-M', '--', oldName, newName], path, 'renameBranch')
      return
    }
    throw error
  }
}

export async function deleteBranch(
  path: string,
  name: string,
  opts: { force?: boolean; deleteRemote?: boolean } = {}
): Promise<void> {
  const branch = (await getBranches(path)).find((branch) => branch.name === name)
  if (!branch) throw new HandlerError('unknown', `Unknown branch: ${name}`)
  if (opts.deleteRemote) {
    const remote =
      branch.type === 'remote'
        ? branch.remoteName
        : await getConfigValue(path, `branch.${name}.remote`)
    const merge =
      branch.type === 'remote' && remote
        ? `refs/heads/${name.slice(remote.length + 1)}`
        : await getConfigValue(path, `branch.${name}.merge`)
    if (!remote || remote === '.' || !merge)
      throw new HandlerError('no-upstream', `No remote upstream for ${name}`)
    await git(['push', '--delete', '--', remote, merge], path, 'deleteRemoteBranch')
    // A successful push also removes the remote-tracking ref when fetch refspecs match.
    if (
      branch.type === 'remote' &&
      !(await getBranches(path)).some((item) => item.type === 'remote' && item.name === name)
    )
      return
  }
  await git(
    ['branch', ...(branch.type === 'remote' ? ['-r'] : []), opts.force ? '-D' : '-d', '--', name],
    path,
    'deleteBranch'
  )
}
