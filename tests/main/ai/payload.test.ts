import { describe, expect, it } from 'vitest'
import { DiffParser } from '../../../src/main/git/diff-parser'
import { AppFileStatusKind } from '../../../src/shared/models/status'
import { selectAll, selectNone, withLineSelection } from '../../../src/shared/models/diff-selection'
import { buildPayload, FILE_LIMIT, TOTAL_LIMIT, TRUNCATED } from '../../../src/main/ai/payload'
import type { FileDiff } from '../../../src/shared/models/diff'

function textDiff(text: string): FileDiff {
  const parsed = new DiffParser().parse(text)
  return {
    kind: 'text',
    text: parsed.contents,
    hunks: parsed.hunks,
    maxLineNumber: parsed.maxLineNumber,
    hasHiddenBidiChars: parsed.hasHiddenBidiChars,
  }
}
const raw = '--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1,2 @@\n+chosen\n+omitted\n'
const diff = textDiff(raw)
const files = async () => [
  { path: 'new.txt', status: { kind: AppFileStatusKind.Untracked as const } },
]
describe('AI outgoing payload', () => {
  it('includes only selected additions using the patch formatter', async () => {
    if (diff.kind !== 'text') throw new Error()
    const line = diff.hunks
      .flatMap((h) => h.lines)
      .find((l) => l.text === '+chosen')!.originalLineNumber!
    const payload = await buildPayload(
      process.cwd(),
      { files: [{ path: 'new.txt', selection: withLineSelection(selectNone(), line, true) }] },
      { files, diff: async () => diff }
    )
    expect(payload).toContain('+chosen')
    expect(payload).not.toContain('omitted')
    expect(payload).toContain('@@ -0,0 +1 @@')
  })
  it('sends binary and image names only and omits deselected files', async () => {
    const payload = await buildPayload(
      process.cwd(),
      { files: [{ path: 'new.txt', selection: selectAll() }] },
      {
        files,
        diff: async () => ({
          kind: 'image',
          current: { contents: 'secret-base64', bytes: 10, mediaType: 'image/png' },
        }),
      }
    )
    expect(payload).toBe('new.txt')
    await expect(
      buildPayload(
        process.cwd(),
        { files: [{ path: 'new.txt', selection: selectNone() }] },
        { files, diff: async () => ({ kind: 'binary' }) }
      )
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
  })
  it('limits each file and the total and visibly marks truncation', async () => {
    const large = textDiff(
      '--- /dev/null\n+++ b/new.txt\n@@ -0,0 +1 @@\n+' + 'x'.repeat(6000) + '\n'
    )
    const inputFiles = Array.from({ length: 10 }, (_, i) => ({
      path: `${i}.txt`,
      selection: selectAll(),
    }))
    const dependencies = {
      files: async () =>
        inputFiles.map((f) => ({
          path: f.path,
          status: { kind: AppFileStatusKind.Untracked as const },
        })),
      diff: async () => large,
    }
    const single = await buildPayload(
      process.cwd(),
      { files: inputFiles.slice(0, 1) },
      dependencies
    )
    expect(single).toHaveLength(FILE_LIMIT)
    expect(single.endsWith(TRUNCATED)).toBe(true)
    const payload = await buildPayload(process.cwd(), { files: inputFiles }, dependencies)
    expect(payload).toHaveLength(TOTAL_LIMIT)
    expect(payload.endsWith(TRUNCATED)).toBe(true)
  })
  it('rejects paths outside the repository and stale files', async () => {
    const dependencies = { files, diff: async () => diff }
    await expect(
      buildPayload(
        process.cwd(),
        { files: [{ path: '../secret', selection: selectAll() }] },
        dependencies
      )
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
    await expect(
      buildPayload(
        process.cwd(),
        { files: [{ path: 'missing', selection: selectAll() }] },
        dependencies
      )
    ).rejects.toMatchObject({ kind: 'not-found' })
  })
})
