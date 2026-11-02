// Ported from GitHub Desktop (MIT): app/src/lib/git/for-each-ref.ts
import type { Branch } from '@shared/models/git'
import { git } from './core'
import { getRemotes } from './remote'

export async function getBranches(path: string): Promise<ReadonlyArray<Branch>> {
  const remotes = await getRemotes(path)
  const fields = ['refname', 'upstream:short', 'objectname', 'committerdate:unix', 'HEAD', 'symref']
  const { stdout } = await git(
    [
      'for-each-ref',
      `--format=${fields.map((field) => `%(${field})`).join('%00')}`,
      'refs/heads',
      'refs/remotes',
    ],
    path,
    'getBranches'
  )
  return stdout
    .split('\n')
    .filter(Boolean)
    .flatMap((line): Branch[] => {
      const [ref, upstream, tipSha, date, head, symref] = line.split('\0')
      if (symref) return []
      const local = ref.startsWith('refs/heads/')
      const name = ref.slice(local ? 'refs/heads/'.length : 'refs/remotes/'.length)
      const remoteName = local
        ? undefined
        : [...remotes]
            .sort((a, b) => b.name.length - a.name.length)
            .find((remote) => name.startsWith(`${remote.name}/`))?.name
      return [
        {
          name,
          type: local ? 'local' : 'remote',
          remoteName,
          upstream: upstream || undefined,
          tipSha,
          tipDate: date ? Number(date) * 1000 : undefined,
          isCurrent: head === '*',
        },
      ]
    })
}
