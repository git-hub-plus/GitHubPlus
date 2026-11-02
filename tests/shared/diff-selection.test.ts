import { describe, expect, it } from 'vitest'
import {
  getSelectionType,
  isRangeSelected,
  isSelected,
  selectAll,
  selectNone,
  withLineSelection,
  withRangeSelection,
  withSelectableLines,
  withToggledLine,
} from '@shared/models/diff-selection'

describe('diff selection', () => {
  const selectable = [2, 3, 4, 7]

  it('starts uniform', () => {
    expect(getSelectionType(selectAll(selectable))).toBe('all')
    expect(getSelectionType(selectNone(selectable))).toBe('none')
    expect(isSelected(selectAll(), 5)).toBe(true)
    expect(isSelected(selectNone(), 5)).toBe(false)
  })

  it('becomes partial when one line is toggled', () => {
    const selection = withToggledLine(selectAll(selectable), 3)
    expect(getSelectionType(selection)).toBe('partial')
    expect(isSelected(selection, 3)).toBe(false)
    expect(isSelected(selection, 2)).toBe(true)
  })

  it('collapses back to uniform when every selectable line diverges', () => {
    let selection = selectAll(selectable)
    for (const line of selectable) {
      selection = withLineSelection(selection, line, false)
    }
    expect(getSelectionType(selection)).toBe('none')
  })

  it('ignores non-selectable lines in ranges', () => {
    const selection = withRangeSelection(selectNone(selectable), 3, 3, true)
    expect(selection.divergingLines).toEqual([3, 4])
    expect(isRangeSelected(selection, 3, 2)).toBe('all')
    expect(isRangeSelected(selection, 2, 3)).toBe('partial')
  })

  it('returns the same object when nothing changes', () => {
    const selection = selectAll(selectable)
    expect(withLineSelection(selection, 2, true)).toBe(selection)
  })

  it('drops diverging lines that are no longer selectable', () => {
    const selection = withSelectableLines(withToggledLine(selectAll(), 9), selectable)
    expect(selection.divergingLines).toEqual([])
    expect(getSelectionType(selection)).toBe('all')
  })

  it('stays plain data for IPC', () => {
    const selection = withToggledLine(selectAll(selectable), 4)
    expect(structuredClone(selection)).toEqual(selection)
  })
})
