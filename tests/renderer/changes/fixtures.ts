// @vitest-environment jsdom
import { DiffLineType, type FileDiff } from '@shared/models/diff'
import { AppFileStatusKind, type RepoStatus } from '@shared/models/status'
export const diff: FileDiff = {
  kind: 'text',
  text: '',
  maxLineNumber: 2,
  hasHiddenBidiChars: false,
  hunks: [
    {
      header: { oldStartLine: 1, oldLineCount: 1, newStartLine: 1, newLineCount: 2 },
      unifiedDiffStart: 0,
      unifiedDiffEnd: 3,
      lines: [
        {
          text: '-old',
          type: DiffLineType.Delete,
          originalLineNumber: 1,
          oldLineNumber: 1,
          newLineNumber: null,
          noTrailingNewLine: false,
        },
        {
          text: '+new',
          type: DiffLineType.Add,
          originalLineNumber: 2,
          oldLineNumber: null,
          newLineNumber: 1,
          noTrailingNewLine: false,
        },
        {
          text: ' context',
          type: DiffLineType.Context,
          originalLineNumber: 3,
          oldLineNumber: 2,
          newLineNumber: 2,
          noTrailingNewLine: false,
        },
      ],
    },
  ],
}
export const status: RepoStatus = {
  currentBranch: 'main',
  ahead: 0,
  behind: 0,
  stashCount: 0,
  files: [
    { path: 'src/a.ts', status: { kind: AppFileStatusKind.Modified } },
    {
      path: 'b.ts',
      status: {
        kind: AppFileStatusKind.Renamed,
        oldPath: 'old.ts',
        renameIncludesModifications: false,
      },
    },
  ],
}
