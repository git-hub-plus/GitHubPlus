import { useEffect, useId, useRef, useState, type ReactNode } from 'react'
import styles from './HistoryView.module.css'

/** Temporary U1-compatible list; paging and activation extend the shared props. */
export function VirtualList<T>({
  items,
  rowHeight,
  renderRow,
  selectedIndex = -1,
  onSelect,
  getKey,
  label,
  onEndReached,
  onActivate,
}: {
  items: ReadonlyArray<T>
  rowHeight: number
  renderRow(item: T, index: number): ReactNode
  selectedIndex?: number
  onSelect?(index: number): void
  getKey(item: T): string
  label: string
  onEndReached?(): void
  onActivate?(): void
}) {
  const ref = useRef<HTMLDivElement>(null)
  const id = useId()
  const [viewport, setViewport] = useState({ top: 0, height: 280 })
  useEffect(() => {
    const element = ref.current
    if (!element || typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(() =>
      setViewport({ top: element.scrollTop, height: element.clientHeight || 280 })
    )
    observer.observe(element)
    return () => observer.disconnect()
  }, [])
  useEffect(() => {
    const element = ref.current
    if (!element) return
    const top = Math.max(0, selectedIndex) * rowHeight
    if (top < element.scrollTop) element.scrollTop = top
    else if (top + rowHeight > element.scrollTop + (element.clientHeight || 280))
      element.scrollTop = top + rowHeight - (element.clientHeight || 280)
    setViewport({ top: element.scrollTop, height: element.clientHeight || 280 })
  }, [selectedIndex, rowHeight])
  const safeTop = Math.min(viewport.top, Math.max(0, items.length * rowHeight - viewport.height))
  const start = Math.max(0, Math.floor(safeTop / rowHeight) - 4)
  const end = Math.min(items.length, Math.ceil((safeTop + viewport.height) / rowHeight) + 4)
  return (
    <div
      ref={ref}
      className={styles.virtual}
      role="listbox"
      aria-label={label}
      aria-activedescendant={
        selectedIndex >= start && selectedIndex < end ? `${id}-${selectedIndex}` : undefined
      }
      tabIndex={0}
      onKeyDown={(event) => {
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault()
          if (items.length)
            onSelect?.(
              Math.max(
                0,
                Math.min(items.length - 1, selectedIndex + (event.key === 'ArrowDown' ? 1 : -1))
              )
            )
        } else if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault()
          onActivate?.()
        }
      }}
      onScroll={(event) => {
        const element = event.currentTarget
        setViewport({ top: element.scrollTop, height: element.clientHeight || 280 })
        if (element.scrollTop + element.clientHeight >= element.scrollHeight - rowHeight * 3)
          onEndReached?.()
      }}
    >
      <div className={styles.virtualInner} style={{ height: items.length * rowHeight }}>
        {items.slice(start, end).map((item, offset) => {
          const index = start + offset
          return (
            <div
              role="option"
              id={`${id}-${index}`}
              aria-selected={index === selectedIndex}
              aria-posinset={index + 1}
              aria-setsize={items.length}
              key={getKey(item)}
              className={styles.virtualRow}
              style={{ top: index * rowHeight, height: rowHeight }}
              onClick={() => {
                ref.current?.focus()
                onSelect?.(index)
              }}
            >
              {renderRow(item, index)}
            </div>
          )
        })}
      </div>
    </div>
  )
}
