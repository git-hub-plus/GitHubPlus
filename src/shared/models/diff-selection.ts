// Ported from GitHub Desktop (MIT): app/src/models/diff/diff-selection.ts
// The immutable class became pure functions over `DiffSelectionData` so the
// same selection can be edited in the renderer and sent to main over IPC.
import type { DiffSelectionData } from './diff'

export type SelectionType = 'all' | 'partial' | 'none'

function typeMatchesSelection(type: SelectionType, selected: boolean): boolean {
  if (type === 'all') return selected
  if (type === 'none') return !selected
  return false
}

function make(
  defaultSelectionType: 'all' | 'none',
  divergingLines: Iterable<number>,
  selectableLines: ReadonlyArray<number> | undefined
): DiffSelectionData {
  const lines = [...divergingLines].sort((a, b) => a - b)
  return selectableLines
    ? { defaultSelectionType, divergingLines: lines, selectableLines }
    : { defaultSelectionType, divergingLines: lines }
}

export function selectAll(selectableLines?: ReadonlyArray<number>): DiffSelectionData {
  return make('all', [], selectableLines)
}

export function selectNone(selectableLines?: ReadonlyArray<number>): DiffSelectionData {
  return make('none', [], selectableLines)
}

/** Overall state of the selection, as used for the file's checkbox. */
export function getSelectionType(selection: DiffSelectionData): SelectionType {
  const { defaultSelectionType, divergingLines, selectableLines } = selection
  if (divergingLines.length === 0) {
    return defaultSelectionType
  }
  if (selectableLines && selectableLines.length === divergingLines.length) {
    const diverging = new Set(divergingLines)
    if (selectableLines.every((line) => diverging.has(line))) {
      return defaultSelectionType === 'all' ? 'none' : 'all'
    }
  }
  return 'partial'
}

export function isSelected(selection: DiffSelectionData, line: number): boolean {
  const divergent = selection.divergingLines.includes(line)
  return selection.defaultSelectionType === 'all' ? !divergent : divergent
}

export function isSelectable(selection: DiffSelectionData, line: number): boolean {
  return selection.selectableLines ? selection.selectableLines.includes(line) : true
}

/** Selection state of `length` lines starting at `from`. */
export function isRangeSelected(
  selection: DiffSelectionData,
  from: number,
  length: number
): SelectionType {
  if (length <= 0) {
    return 'none'
  }
  const overall = getSelectionType(selection)
  if (overall !== 'partial') {
    return overall
  }
  let foundSelected = false
  let foundDeselected = false
  for (let i = from; i < from + length; i++) {
    if (isSelected(selection, i)) foundSelected = true
    else foundDeselected = true
    if (foundSelected && foundDeselected) return 'partial'
  }
  return foundSelected ? 'all' : 'none'
}

export function withRangeSelection(
  selection: DiffSelectionData,
  from: number,
  length: number,
  selected: boolean
): DiffSelectionData {
  const overall = getSelectionType(selection)
  const to = from + length
  if (typeMatchesSelection(overall, selected)) {
    return selection
  }
  if (overall === 'partial') {
    const next = new Set(selection.divergingLines)
    if (typeMatchesSelection(selection.defaultSelectionType, selected)) {
      for (let i = from; i < to; i++) next.delete(i)
    } else {
      for (let i = from; i < to; i++) {
        if (isSelectable(selection, i)) next.add(i)
      }
    }
    return make(selection.defaultSelectionType, next, selection.selectableLines)
  }
  // Uniform selection: flip the default and record the changed range.
  const next = new Set<number>()
  for (let i = from; i < to; i++) {
    if (isSelectable(selection, i)) next.add(i)
  }
  return make(overall, next, selection.selectableLines)
}

export function withLineSelection(
  selection: DiffSelectionData,
  line: number,
  selected: boolean
): DiffSelectionData {
  return withRangeSelection(selection, line, 1, selected)
}

export function withToggledLine(selection: DiffSelectionData, line: number): DiffSelectionData {
  return withLineSelection(selection, line, !isSelected(selection, line))
}

/** Restricts the selection to the given selectable lines (call after loading a diff). */
export function withSelectableLines(
  selection: DiffSelectionData,
  selectableLines: ReadonlyArray<number>
): DiffSelectionData {
  const allowed = new Set(selectableLines)
  return make(
    selection.defaultSelectionType,
    selection.divergingLines.filter((line) => allowed.has(line)),
    selectableLines
  )
}
