import type { Commit } from '@shared/models/git'

export interface GraphEdge {
  readonly fromLane: number
  readonly toLane: number
  readonly color: number
  readonly type: 'incoming' | 'continue' | 'parent' | 'merge'
}
export interface GraphRow {
  readonly lane: number
  readonly color: number
  readonly width: number
  readonly edges: ReadonlyArray<GraphEdge>
}
export interface GraphState {
  readonly lanes: ReadonlyArray<{ readonly sha: string; readonly color: number } | null>
  readonly nextColor: number
}
export const emptyGraphState = (): GraphState => ({ lanes: [], nextColor: 0 })

/** Stable slots keep edges continuous across both rows and page boundaries. */
export function calculateCommitGraph(
  commits: ReadonlyArray<Commit>,
  previous: GraphState = emptyGraphState()
): { rows: GraphRow[]; state: GraphState } {
  const lanes = [...previous.lanes]
  let nextColor = previous.nextColor
  const rows = commits.map((commit): GraphRow => {
    let lane = lanes.findIndex((entry) => entry?.sha === commit.sha)
    const incoming = lane !== -1
    if (!incoming) {
      lane = lanes.indexOf(null)
      if (lane === -1) lane = lanes.length
      lanes[lane] = { sha: commit.sha, color: nextColor++ % 6 }
    }
    const color = lanes[lane]!.color
    const width = lanes.length
    const edges: GraphEdge[] = []
    lanes.forEach((entry, index) => {
      if (entry)
        edges.push({
          fromLane: index,
          toLane: index,
          color: entry.color,
          type: index === lane ? 'incoming' : 'continue',
        })
    })
    if (!incoming)
      edges.splice(
        edges.findIndex((edge) => edge.fromLane === lane),
        1
      )
    lanes[lane] = null
    commit.parentShas.forEach((sha, index) => {
      let target = lanes.findIndex((entry) => entry?.sha === sha)
      if (target === -1) {
        target = index === 0 ? lane : lanes.indexOf(null)
        if (target === -1) target = lanes.length
        lanes[target] = { sha, color: index === 0 ? color : nextColor++ % 6 }
      }
      edges.push({
        fromLane: lane,
        toLane: target,
        color: lanes[target]!.color,
        type: index === 0 ? 'parent' : 'merge',
      })
    })
    const row = { lane, color, width: Math.max(width, lanes.length), edges }
    while (lanes.length && lanes[lanes.length - 1] === null) lanes.pop()
    return row
  })
  return { rows, state: { lanes, nextColor } }
}
