import type { Branch, Commit } from '@shared/models/git'

/** Reachability is based on parent links, never on log/date ordering. */
export function historyPolicy(commits: ReadonlyArray<Commit>, branches: ReadonlyArray<Branch>) {
  const bySha = new Map(commits.map((commit) => [commit.sha, commit]))
  const ancestors = (tips: ReadonlyArray<string>) => {
    const found = new Set<string>()
    const pending = [...tips]
    while (pending.length) {
      const sha = pending.pop()!
      if (found.has(sha)) continue
      found.add(sha)
      pending.push(...(bySha.get(sha)?.parentShas ?? []))
    }
    return found
  }
  const current = branches.find((branch) => branch.isCurrent)
  const currentShas = ancestors(current ? [current.tipSha] : [])
  const published = ancestors(
    branches.filter((branch) => branch.type === 'remote').map((branch) => branch.tipSha)
  )
  const remoteBoundaryKnown =
    branches
      .filter((branch) => branch.type === 'remote')
      .every((branch) => bySha.has(branch.tipSha)) &&
    (!current?.upstream || branches.some((branch) => branch.name === current.upstream)) &&
    [...published].every((sha) => bySha.has(sha) || currentShas.has(sha))
  const currentComplete = [...currentShas].every((sha) => bySha.has(sha))
  const otherShas = ancestors(
    branches.filter((branch) => !branch.isCurrent).map((branch) => branch.tipSha)
  )
  // A linear HEAD path supplies an unambiguous oldest-first order for edits.
  const path: string[] = []
  const seen = new Set<string>()
  let next = current?.tipSha
  while (next && !seen.has(next)) {
    const commit = bySha.get(next)
    if (!commit || commit.parentShas.length > 1) break
    path.push(next)
    seen.add(next)
    next = commit.parentShas[0]
  }
  const completePath = path.length > 0 && bySha.get(path.at(-1)!)?.parentShas.length === 0
  return {
    current,
    currentShas,
    published,
    otherShas,
    path,
    remoteBoundaryKnown,
    currentComplete,
    completePath,
  }
}

export function reorderPlan(
  path: ReadonlyArray<string>,
  shas: ReadonlyArray<string>,
  afterSha: string | null
) {
  const moved = path.filter((sha) => shas.includes(sha)).reverse()
  if (
    !moved.length ||
    moved.length !== shas.length ||
    (afterSha !== null && (!path.includes(afterSha) || shas.includes(afterSha)))
  )
    return undefined
  const remaining = [...path].reverse().filter((sha) => !shas.includes(sha))
  const at = afterSha === null ? 0 : remaining.indexOf(afterSha) + 1
  const result = [...remaining.slice(0, at), ...moved, ...remaining.slice(at)]
  const original = [...path].reverse()
  const firstChanged = original.findIndex((sha, index) => result[index] !== sha)
  if (firstChanged < 0) return undefined
  return { shas: moved, afterSha, rewritten: original.slice(firstChanged) }
}
