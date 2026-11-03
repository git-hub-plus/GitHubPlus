import type { GitAuthProvider } from '../git/core'

export function isGitHubHttps(value: string): boolean {
  try {
    const url = new URL(value)
    return (
      url.protocol === 'https:' &&
      url.hostname === 'github.com' &&
      !url.port &&
      !url.username &&
      !url.password
    )
  } catch {
    return false
  }
}

export function createGitHubAuthProvider(
  getToken: () => string | undefined,
  getOrigin: (path: string) => string | undefined
): GitAuthProvider {
  return (args, path) => {
    const token = getToken()
    let command = 0
    while (args[command] === '-c') command += 2
    if (
      !token ||
      !['clone', 'fetch', 'pull', 'push', 'ls-remote'].includes(args[command] ?? '') ||
      args.includes('--get-url')
    )
      return undefined
    const targets = args.slice(command + 1)
    const urls = targets.filter((arg) => /^(?:[a-z][a-z\d+.-]*:\/\/|[^/]+@[^:]+:)/i.test(arg))
    if (urls.length ? !urls.every(isGitHubHttps) : !isGitHubHttps(getOrigin(path) ?? ''))
      return undefined
    // Named remotes other than origin cannot be inferred from the origin cache.
    const positional = targets.filter((arg) => !arg.startsWith('-'))
    if (!urls.length && positional.length && positional[0] !== 'origin') return undefined
    if (args[command] === 'clone' && !urls.length) return undefined
    const encoded = Buffer.from(`x-access-token:${token}`).toString('base64')
    return {
      configArgs: [
        '-c',
        `http.https://github.com/.extraheader=AUTHORIZATION: basic ${encoded}`,
        '-c',
        'credential.helper=',
      ],
    }
  }
}
