// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, expect, it, vi } from 'vitest'
import { ContextMenu } from '@renderer/components/common/ContextMenu'
import { ConfirmDialog } from '@renderer/components/common/ConfirmDialog'
afterEach(cleanup)
it('focuses menu actions, handles arrows and closes on Escape or outside pointer', () => {
  const close = vi.fn()
  render(
    <ContextMenu
      x={0}
      y={0}
      onClose={close}
      items={[
        { label: 'first', onSelect: vi.fn() },
        { label: 'second', onSelect: vi.fn() },
      ]}
    />
  )
  expect(document.activeElement).toBe(screen.getByText('first'))
  fireEvent.keyDown(screen.getByRole('menu'), { key: 'ArrowDown' })
  expect(document.activeElement).toBe(screen.getByText('second'))
  fireEvent.keyDown(screen.getByRole('menu'), { key: 'Escape' })
  expect(close).toHaveBeenCalledTimes(1)
  fireEvent.pointerDown(document.body)
  expect(close).toHaveBeenCalledTimes(2)
})
it('starts dialog on cancel, traps focus and handles Escape', () => {
  const cancel = vi.fn()
  const confirm = vi.fn()
  render(<ConfirmDialog message="Confirm discard" onCancel={cancel} onConfirm={confirm} />)
  expect(document.activeElement).toBe(screen.getByRole('button', { name: '취소' }))
  fireEvent.keyDown(screen.getByRole('alertdialog'), { key: 'Tab' })
  expect(document.activeElement).toBe(screen.getByRole('button', { name: '변경 사항 버리기' }))
  fireEvent.keyDown(screen.getByRole('alertdialog'), { key: 'Escape' })
  expect(cancel).toHaveBeenCalledOnce()
  expect(confirm).not.toHaveBeenCalled()
})
