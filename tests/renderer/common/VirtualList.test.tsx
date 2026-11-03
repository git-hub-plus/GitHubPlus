// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, expect, it, vi } from 'vitest'
import { VirtualList } from '@renderer/components/common/VirtualList'
import { SplitPane } from '@renderer/components/common/SplitPane'
afterEach(cleanup)
it('renders only a bounded window and updates on scroll', () => {
  const items = Array.from({ length: 10000 }, (_, index) => index)
  const { container } = render(
    <VirtualList
      items={items}
      rowHeight={28}
      getKey={(item) => item}
      renderRow={(item) => <span data-testid="row">row {item}</span>}
    />
  )
  expect(screen.getAllByTestId('row').length).toBeLessThan(25)
  expect(screen.queryByText('row 5000')).toBeNull()
  fireEvent.scroll(container.firstChild!, { target: { scrollTop: 140000 } })
  expect(screen.getByText('row 5000')).toBeTruthy()
  expect(screen.getAllByTestId('row').length).toBeLessThan(25)
})
it('supports arrow and activation keys and scrolls selected rows into view', () => {
  const select = vi.fn()
  const props = {
    items: [0, 1, 2],
    rowHeight: 28,
    getKey: (item: number) => item,
    renderRow: (item: number) => <span>{item}</span>,
    onSelect: select,
  }
  const { container, rerender } = render(<VirtualList {...props} selectedIndex={0} />)
  fireEvent.keyDown(container.firstChild!, { key: 'ArrowDown' })
  expect(select).toHaveBeenLastCalledWith(1)
  fireEvent.keyDown(container.firstChild!, { key: ' ' })
  expect(select).toHaveBeenLastCalledWith(0)
  rerender(<VirtualList {...props} selectedIndex={2} rowHeight={300} />)
  expect((container.firstChild as HTMLElement).scrollTop).toBe(500)
})
it('persists panel width, respects its minimum and restores it', () => {
  localStorage.clear()
  const { unmount } = render(<SplitPane left={<p>left</p>} right={<p>right</p>} />)
  const separator = screen.getByRole('separator')
  expect(separator.getAttribute('aria-valuenow')).toBe('320')
  for (let i = 0; i < 10; i++) fireEvent.keyDown(separator, { key: 'ArrowLeft' })
  expect(separator.getAttribute('aria-valuenow')).toBe('240')
  fireEvent.keyDown(separator, { key: 'ArrowRight' })
  expect(localStorage.getItem('ghp.changesPanelWidth')).toBe('256')
  unmount()
  render(<SplitPane left={null} right={null} />)
  expect(screen.getByRole('separator').getAttribute('aria-valuenow')).toBe('256')
})

it('exposes a labelled list and activates the selected index without selecting again', () => {
  const activate = vi.fn()
  const select = vi.fn()
  const end = vi.fn()
  render(
    <VirtualList
      items={[0, 1, 2]}
      rowHeight={28}
      getKey={(item) => item}
      label="Commits"
      selectedIndex={1}
      onSelect={select}
      onActivate={activate}
      onEndReached={end}
      renderRow={(item) => <span>{item}</span>}
    />
  )
  const list = screen.getByRole('listbox', { name: 'Commits' })
  fireEvent.keyDown(list, { key: 'Enter' })
  expect(activate).toHaveBeenCalledWith(1)
  expect(select).not.toHaveBeenCalled()
  Object.defineProperties(list, { clientHeight: { value: 100 }, scrollHeight: { value: 1000 } })
  fireEvent.scroll(list, { target: { scrollTop: 820 } })
  expect(end).toHaveBeenCalledOnce()
})
it('persists percent splits independently of the existing pixel split', () => {
  localStorage.clear()
  const { unmount } = render(
    <SplitPane
      storageKey="custom.split"
      defaultSize={48}
      minSize={25}
      unit="percent"
      left="left"
      right="right"
    />
  )
  const separator = screen.getByRole('separator')
  expect(separator.getAttribute('aria-valuenow')).toBe('48')
  for (let i = 0; i < 30; i++) fireEvent.keyDown(separator, { key: 'ArrowRight' })
  expect(separator.getAttribute('aria-valuenow')).toBe('75')
  expect(localStorage.getItem('custom.split')).toBe('75')
  expect(localStorage.getItem('ghp.changesPanelWidth')).toBeNull()
  unmount()
  render(
    <SplitPane
      storageKey="custom.split"
      defaultSize={48}
      minSize={25}
      unit="percent"
      left="left"
      right="right"
    />
  )
  expect(screen.getByRole('separator').getAttribute('aria-valuenow')).toBe('75')
})

it('activates a list without requiring an onSelect callback', () => {
  const activate = vi.fn()
  render(
    <VirtualList
      items={['only']}
      rowHeight={28}
      label="Activate"
      getKey={(item) => item}
      onActivate={activate}
      renderRow={(item) => item}
    />
  )
  fireEvent.keyDown(screen.getByRole('listbox'), { key: 'Enter' })
  expect(activate).toHaveBeenCalledWith(0)
})
it('keeps a filtered list visible after a large scroll offset', () => {
  const props = {
    rowHeight: 28,
    getKey: (item: number) => item,
    renderRow: (item: number) => <span>{item}</span>,
  }
  const { container, rerender } = render(
    <VirtualList {...props} items={Array.from({ length: 10000 }, (_, index) => index)} />
  )
  fireEvent.scroll(container.firstChild!, { target: { scrollTop: 140000 } })
  rerender(<VirtualList {...props} items={[0, 1, 2, 3]} />)
  expect(screen.getByText('0')).toBeTruthy()
})
