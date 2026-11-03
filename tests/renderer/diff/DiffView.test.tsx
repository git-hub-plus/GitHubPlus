// @vitest-environment jsdom
import { useState } from 'react'
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { DiffView } from '@renderer/components/diff/DiffView'
import { getSelectionType, selectAll } from '@shared/models/diff-selection'
import { diff } from '../changes/fixtures'
function Harness() {
  const [selection, setSelection] = useState(selectAll())
  return (
    <>
      <output>{getSelectionType(selection)}</output>
      <DiffView diff={diff} path="a.ts" selection={selection} onSelectionChange={setSelection} />
    </>
  )
}
afterEach(cleanup)
describe('diff', () => {
  it('normalizes selectable lines, toggles lines and whole hunks', () => {
    render(<Harness />)
    fireEvent.click(screen.getByLabelText('diff 1번 줄 포함 전환'))
    expect(screen.getByText('partial')).toBeTruthy()
    fireEvent.click(screen.getByLabelText('diff 2번 줄 포함 전환'))
    expect(screen.getByText('none')).toBeTruthy()
    fireEvent.click(screen.getByLabelText(/헝크 포함 전환/))
    expect(screen.getByText('all')).toBeTruthy()
    expect((screen.getByLabelText('diff 3번 줄 포함 전환') as HTMLButtonElement).disabled).toBe(
      true
    )
  })
  it('supports pointer range selection', () => {
    window.PointerEvent = MouseEvent as typeof PointerEvent
    render(<Harness />)
    fireEvent.pointerDown(screen.getByLabelText('diff 1번 줄 포함 전환'), { button: 0 })
    fireEvent.pointerEnter(screen.getByLabelText('diff 2번 줄 포함 전환'))
    fireEvent.pointerUp(window)
    expect(screen.getByText('none')).toBeTruthy()
  })
  it('renders read-only diffs and non-text variants', () => {
    const { rerender } = render(<DiffView diff={diff} path="a.ts" />)
    expect((screen.getByLabelText('diff 1번 줄 포함 전환') as HTMLButtonElement).disabled).toBe(
      true
    )
    rerender(<DiffView diff={{ kind: 'binary' }} path="a" />)
    expect(screen.getByText(/바이너리/)).toBeTruthy()
    rerender(
      <DiffView
        diff={{
          kind: 'image',
          previous: { contents: 'abc', mediaType: 'image/png', bytes: 3 },
          current: { contents: 'def', mediaType: 'image/png', bytes: 3 },
        }}
        path="a.png"
      />
    )
    expect(screen.getByAltText('이전 이미지').getAttribute('src')).toBe('data:image/png;base64,abc')
    expect(screen.getByAltText('새 이미지').getAttribute('src')).toBe('data:image/png;base64,def')
    rerender(<DiffView diff={{ kind: 'unrenderable' }} path="a" />)
    expect(screen.getByText(/표시할 수 없습니다/)).toBeTruthy()
  })
})
