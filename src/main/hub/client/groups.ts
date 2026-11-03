import { getRemotes } from '../../git/remote'
import { loadRepositories, updateRepository } from '../../store/repositories'

/** Reinspect all remotes, including a published secondary `hub` remote. */
export async function refreshHubGroups(matches: (url: string) => boolean): Promise<void> {
  const list = await loadRepositories()
  for (const repo of list) {
    if (!repo.available) continue
    const remote = (await getRemotes(repo.path)).find((remote) => matches(remote.url))
    if (remote && (repo.group !== 'hub' || repo.remoteUrl !== remote.url)) {
      await updateRepository(repo.id, { remoteUrl: remote.url })
    }
  }
}
