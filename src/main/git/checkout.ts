// Ported from GitHub Desktop (MIT): app/src/lib/git/checkout.ts
import { HandlerError } from '@shared/errors'
import { getBranches } from './for-each-ref'
import { runWithProgress, type ProgressCallback } from './progress/from-process'

export async function checkoutBranch(
  path: string,
  name: string,
  progress?: ProgressCallback
): Promise<void> {
  const branches = await getBranches(path)
  const branch =
    branches.find((branch) => branch.name === name && branch.type === 'local') ??
    branches.find((branch) => branch.name === name)
  if (!branch) throw new HandlerError('unknown', `Unknown branch: ${name}`)
  const args = ['checkout', '--progress']
  if (branch.type === 'remote') {
    if (!branch.remoteName) throw new HandlerError('unknown', `Unknown remote for branch: ${name}`)
    args.push('--track', '-b', name.slice(branch.remoteName.length + 1), `refs/remotes/${name}`)
  } else args.push(name)
  args.push('--')
  await runWithProgress(args, path, 'checkout', `Checking out branch ${name}`, progress)
}
