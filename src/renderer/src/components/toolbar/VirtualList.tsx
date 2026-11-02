import { useRef, useState, type ReactNode } from 'react'

/** Temporary U3 list window. Replace with U1's common/VirtualList when merging. */
export function VirtualList<T>({
  items,
  rowHeight,
  renderRow,
  getKey,
  selectedIndex,
  onSelect,
}: {
  items: ReadonlyArray<T>
  rowHeight: number
  renderRow(item: T, index: number): ReactNode
  getKey(item: T): string
  selectedIndex?: number
  onSelect?(index: number): void
}) {
  const [scrollTop, setScrollTop] = useState(0)
  const viewport = useRef<HTMLDivElement>(null)
  const height = Math.min(items.length * rowHeight, 280)
  const start = Math.min(
    Math.max(0, items.length - 1),
    Math.max(0, Math.floor(scrollTop / rowHeight) - 3)
  )
  const count = Math.ceil(height / rowHeight) + 6
  return (
    <div
      ref={viewport}
      style={{ height, overflowY: 'auto' }}
      onScroll={(event) => setScrollTop(event.currentTarget.scrollTop)}
      onKeyDown={(event) => {
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return
        const row = (event.target as HTMLElement).closest<HTMLElement>('[data-virtual-index]')
        if (!row) return
        event.preventDefault()
        event.stopPropagation()
        const index = Math.max(
          0,
          Math.min(
            items.length - 1,
            Number(row.dataset.virtualIndex) + (event.key === 'ArrowDown' ? 1 : -1)
          )
        )
        const nextTop = index * rowHeight
        if (nextTop < scrollTop || nextTop + rowHeight > scrollTop + height) {
          viewport.current!.scrollTop = nextTop
          setScrollTop(nextTop)
        }
        onSelect?.(index)
        const focus = () =>
          viewport.current
            ?.querySelector<HTMLElement>(
              `[data-virtual-index="${index}"] button:not(:disabled), [data-virtual-index="${index}"] [role="option"]`
            )
            ?.focus()
        if (viewport.current?.querySelector(`[data-virtual-index="${index}"]`)) focus()
        else requestAnimationFrame(focus)
      }}
    >
      <div style={{ height: items.length * rowHeight, position: 'relative' }}>
        {items.slice(start, start + count).map((item, offset) => (
          <div
            key={getKey(item)}
            data-virtual-index={start + offset}
            data-selected={selectedIndex === start + offset || undefined}
            style={{
              position: 'absolute',
              top: (start + offset) * rowHeight,
              height: rowHeight,
              width: '100%',
            }}
          >
            {renderRow(item, start + offset)}
          </div>
        ))}
      </div>
    </div>
  )
}
