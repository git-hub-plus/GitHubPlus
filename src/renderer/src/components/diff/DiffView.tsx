import type { DiffSelectionData, FileDiff } from '@shared/models/diff'

export interface DiffViewProps {
  readonly diff: FileDiff
  /** Path shown in the header. */
  readonly path: string
  /**
   * When set, lines can be (de)selected for the next commit (changes view).
   * Omit for read-only diffs (history view).
   */
  readonly selection?: DiffSelectionData
  readonly onSelectionChange?: (selection: DiffSelectionData) => void
}

/**
 * Renders a file diff (text with line numbers, image, binary, submodule...).
 * Owner: worker U1. This stub keeps the props contract so U2 can use it.
 */
export function DiffView({ path }: DiffViewProps) {
  return <div data-testid="diff-view">{path}</div>
}
