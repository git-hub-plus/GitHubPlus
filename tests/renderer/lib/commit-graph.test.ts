// @vitest-environment jsdom
import { describe, expect, it } from 'vitest'
import type { Commit } from '@shared/models/git'
import { calculateCommitGraph } from '../../../src/renderer/src/lib/commit-graph'

const commit = (sha: string, ...parentShas: string[]): Commit => ({
  sha,
  shortSha: sha,
  parentShas,
  summary: sha,
  body: '',
  tags: [],
  author: { name: 'Test', email: 'test@example.com', date: 0, tzOffset: 0 },
  committer: { name: 'Test', email: 'test@example.com', date: 0, tzOffset: 0 },
})

describe('commit graph', () => {
  it('keeps a straight history in one lane', () => {
    const { rows, state } = calculateCommitGraph([commit('c', 'b'), commit('b', 'a'), commit('a')])
    expect(rows.map(({ lane }) => lane)).toEqual([0, 0, 0])
    expect(rows.map(({ color }) => color)).toEqual([0, 0, 0])
    expect(rows[1].edges).toEqual([
      { fromLane: 0, toLane: 0, color: 0, type: 'incoming' },
      { fromLane: 0, toLane: 0, color: 0, type: 'parent' },
    ])
    expect(state.lanes).toEqual([])
  })
  it('opens a merge lane and joins both branch paths at their common ancestor', () => {
    const { rows } = calculateCommitGraph([
      commit('merge', 'left', 'right'),
      commit('left', 'root'),
      commit('right', 'root'),
      commit('root'),
    ])
    expect(rows.map(({ lane }) => lane)).toEqual([0, 0, 1, 0])
    expect(rows[0].edges).toContainEqual({ fromLane: 0, toLane: 1, color: 1, type: 'merge' })
    expect(rows[1].edges).toContainEqual({ fromLane: 1, toLane: 1, color: 1, type: 'continue' })
    expect(rows[2].edges).toContainEqual({ fromLane: 1, toLane: 0, color: 0, type: 'parent' })
  })
  it('supports independent roots, octopus merges and reused lanes', () => {
    const { rows, state } = calculateCommitGraph([
      commit('m', 'a', 'b', 'c'),
      commit('a'),
      commit('b'),
      commit('c'),
      commit('other'),
    ])
    expect(rows.map(({ lane }) => lane)).toEqual([0, 0, 1, 2, 0])
    expect(rows[4].color).toBe(3)
    expect(rows[4].edges).toEqual([])
    expect(state.lanes).toEqual([])
  })
  it('matches a single pass at every page boundary without mutating prior state', () => {
    const commits = [
      commit('m', 'a', 'b'),
      commit('a', 'root'),
      commit('b', 'root'),
      commit('root'),
      commit('other'),
    ]
    const whole = calculateCommitGraph(commits)
    for (let split = 0; split <= commits.length; split++) {
      const first = calculateCommitGraph(commits.slice(0, split))
      const snapshot = JSON.stringify(first.state)
      const second = calculateCommitGraph(commits.slice(split), first.state)
      expect([...first.rows, ...second.rows]).toEqual(whole.rows)
      expect(second.state).toEqual(whole.state)
      expect(JSON.stringify(first.state)).toBe(snapshot)
    }
  })
})
