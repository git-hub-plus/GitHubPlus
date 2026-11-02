// Ported from GitHub Desktop (MIT): app/test/unit/patch-formatter-test.ts
import { describe, it } from 'vitest'
import assert from 'node:assert'
import { AppFileStatusKind } from '@shared/models/status'
import { selectNone, withLineSelection } from '@shared/models/diff-selection'
import { DiffParser } from '../../../src/main/git/diff-parser'
import type { SelectedFile } from '../../../src/main/git/apply'
import { formatPatch } from '../../../src/main/git/patch-formatter'
async function parseDiff(text: string) {
  return { ...new DiffParser().parse(text), text }
}
describe('patch formatting', () => {
  describe('formatPatchesForModifiedFile', () => {
    it("doesn't include unselected added lines as context", async () => {
      const rawDiff = [
        '--- a/file.md',
        '+++ b/file.md',
        '@@ -10,2 +10,4 @@',
        ' context',
        '+added line 1',
        '+added line 2',
        ' context',
      ].join('\n')

      const diff = await parseDiff(rawDiff)

      // Select the second added line
      const selection = withLineSelection(selectNone(), 3, true)

      const file: SelectedFile = {
        path: 'file.md',
        status: { kind: AppFileStatusKind.Modified },
        selection,
      }
      const patch = formatPatch(file, diff)

      assert.equal(
        patch,
        `--- a/file.md
+++ b/file.md
@@ -10,2 +10,3 @@
 context
+added line 2
 context
`
      )
    })

    it('rewrites hunk header when necessary', async () => {
      const rawDiff = [
        '--- /dev/null',
        '+++ b/file.md',
        '@@ -0,2 +1,2 @@',
        '+added line 1',
        '+added line 2',
      ].join('\n')
      const diff = await parseDiff(rawDiff)

      // Select the second added line
      const selection = withLineSelection(selectNone(), 2, true)

      const file: SelectedFile = {
        path: 'file.md',
        status: { kind: AppFileStatusKind.New },
        selection,
      }
      const patch = formatPatch(file, diff)

      assert(patch.includes('@@ -0,0 +1 @@'))
      assert(patch.includes('+added line 2'))
    })

    it('includes empty context lines', async () => {
      const rawDiff = [
        '--- a/file.md',
        '+++ b/file.md',
        '@@ -1 +1,2 @@',
        ' ',
        '+added line 2',
      ].join('\n')
      const diff = await parseDiff(rawDiff)

      // Select the second added line
      const selection = withLineSelection(selectNone(), 2, true)

      const file: SelectedFile = {
        path: 'file.md',
        status: { kind: AppFileStatusKind.Modified },
        selection,
      }
      const patch = formatPatch(file, diff)

      assert(patch.includes('@@ -1 +1,2 @@'))
      assert(patch.includes(' '))
      assert(patch.includes('+added line 2'))
    })

    it('creates the right patch when a `No newline` marker is involved', async () => {
      const rawDiff = [
        '--- a/file.md',
        '+++ b/file.md',
        '@@ -23,5 +24,5 @@ and more stuff',
        ' ',
        ' ',
        ' ',
        '-',
        '-and fun stuff? I dnno',
        '\\ No newline at end of file',
        '+and fun stuff? I dnno',
        '+it could be,',
      ].join('\n')
      const diff = await parseDiff(rawDiff)

      // Select the second added line
      const selection = withLineSelection(selectNone(), 7, true)

      const file: SelectedFile = {
        path: 'file.md',
        status: { kind: AppFileStatusKind.Modified },
        selection,
      }

      const patch = formatPatch(file, diff)

      assert(patch.includes('\\ No newline at end of file'))
      assert(patch.includes('+it could be'))
    })
  })
})
