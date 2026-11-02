// Ported from GitHub Desktop (MIT): app/src/lib/git/config.ts
import { git } from './core'

export async function getConfigValue(path: string, key: string): Promise<string | undefined> {
  const result = await git(['config', '--null', '--get', key], path, 'getConfigValue', {
    successExitCodes: new Set([0, 1]),
  })
  return result.exitCode === 1 ? undefined : result.stdout.slice(0, -1)
}
