// Diff shapes are adapted from GitHub Desktop (MIT) `app/src/models/diff/*` as
// plain data (no classes) so they can cross the IPC boundary.
import type { SubmoduleStatus } from './status'

export enum DiffLineType {
  Context = 'Context',
  Add = 'Add',
  Delete = 'Delete',
  Hunk = 'Hunk',
}

export interface DiffLine {
  readonly text: string
  readonly type: DiffLineType
  /** Line index in the unified diff output; used for line selection. */
  readonly originalLineNumber: number | null
  readonly oldLineNumber: number | null
  readonly newLineNumber: number | null
  readonly noTrailingNewLine: boolean
}

export interface DiffHunkHeader {
  readonly oldStartLine: number
  readonly oldLineCount: number
  readonly newStartLine: number
  readonly newLineCount: number
}

export interface DiffHunk {
  readonly header: DiffHunkHeader
  readonly lines: ReadonlyArray<DiffLine>
  readonly unifiedDiffStart: number
  readonly unifiedDiffEnd: number
}

export type LineEnding = 'CR' | 'LF' | 'CRLF'

export interface TextDiffData {
  readonly text: string
  readonly hunks: ReadonlyArray<DiffHunk>
  readonly lineEndingsChange?: { readonly from: LineEnding; readonly to: LineEnding }
  readonly maxLineNumber: number
  readonly hasHiddenBidiChars: boolean
}

export interface DiffImage {
  /** Base64 encoded file contents. */
  readonly contents: string
  readonly mediaType: string
  readonly bytes: number
}

export type FileDiff =
  | ({ readonly kind: 'text' } & TextDiffData)
  | ({ readonly kind: 'large' } & TextDiffData)
  | { readonly kind: 'binary' }
  | { readonly kind: 'image'; readonly previous?: DiffImage; readonly current?: DiffImage }
  | {
      readonly kind: 'submodule'
      readonly path: string
      readonly url: string | null
      readonly status: SubmoduleStatus
      readonly oldSha: string | null
      readonly newSha: string | null
    }
  | { readonly kind: 'unrenderable' }

/**
 * Which lines of a working file are included in the next commit.
 *
 * Plain-data form of GitHub Desktop's `DiffSelection`: every selectable line
 * follows `defaultSelectionType` except those listed in `divergingLines`.
 * Line numbers refer to `DiffLine.originalLineNumber`.
 */
export interface DiffSelectionData {
  readonly defaultSelectionType: 'all' | 'none'
  readonly divergingLines: ReadonlyArray<number>
  /** When known, restricts selection to these lines (added/deleted lines). */
  readonly selectableLines?: ReadonlyArray<number>
}
