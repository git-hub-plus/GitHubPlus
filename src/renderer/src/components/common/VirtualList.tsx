import { useLayoutEffect, useRef, useState, type ReactNode, type Key } from 'react'
import styles from './VirtualList.module.css'

export interface VirtualListProps<T> {
  items: ReadonlyArray<T>
  rowHeight: number
  renderRow(item: T, index: number): ReactNode
  selectedIndex?: number
  onSelect?(index: number): void
  getKey(item: T): Key
}

export function VirtualList<T>({
  items,
  rowHeight,
  renderRow,
  selectedIndex,
  onSelect,
  getKey,
}: VirtualListProps<T>) {
  const ref = useRef<HTMLDivElement>(null)
  const [viewport, setViewport] = useState({ top: 0, height: 400 })
  useLayoutEffect(() => {
    const element = ref.current!
    const measure = () =>
      setViewport({ top: element.scrollTop, height: element.clientHeight || 400 })
    measure()
    if (typeof ResizeObserver === 'undefined') return
    const observer = new ResizeObserver(measure)
    observer.observe(element)
    return () => observer.disconnect()
  }, [])
  useLayoutEffect(() => {
    const element = ref.current
    if (!element || selectedIndex === undefined || selectedIndex < 0) return
    const top = selectedIndex * rowHeight
    const height = element.clientHeight || 400
    if (top < element.scrollTop) element.scrollTop = top
    else if (top + rowHeight > element.scrollTop + height)
      element.scrollTop = top + rowHeight - height
    setViewport({ top: element.scrollTop, height })
  }, [selectedIndex, rowHeight])
  const start = Math.max(
    0,
    Math.min(Math.floor(viewport.top / rowHeight), Math.max(0, items.length - 1)) - 3
  )
  const end = Math.min(items.length, start + Math.ceil(viewport.height / rowHeight) + 6)
  return (
    <div
      ref={ref}
      className={styles.viewport}
      tabIndex={onSelect ? 0 : undefined}
      onScroll={(event) =>
        setViewport({
          top: event.currentTarget.scrollTop,
          height: event.currentTarget.clientHeight || 400,
        })
      }
      onKeyDown={(event) => {
        if (!onSelect || !items.length) return
        const index = Math.max(0, selectedIndex ?? 0)
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault()
          event.currentTarget.focus()
          onSelect(
            Math.max(0, Math.min(items.length - 1, index + (event.key === 'ArrowDown' ? 1 : -1)))
          )
        } else if (
          event.target === event.currentTarget &&
          (event.key === 'Enter' || event.key === ' ')
        ) {
          event.preventDefault()
          onSelect(index)
        }
      }}
    >
      <div className={styles.content} style={{ height: items.length * rowHeight }}>
        {items.slice(start, end).map((item, offset) => (
          <div
            key={getKey(item)}
            className={styles.row}
            style={{ top: (start + offset) * rowHeight, height: rowHeight }}
          >
            {renderRow(item, start + offset)}
          </div>
        ))}
      </div>
    </div>
  )
}
