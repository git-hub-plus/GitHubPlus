import { useId, useLayoutEffect, useRef, useState, type ReactNode, type Key } from 'react'
import styles from './VirtualList.module.css'

export interface VirtualListProps<T> {
  items: ReadonlyArray<T>
  rowHeight: number
  renderRow(item: T, index: number): ReactNode
  selectedIndex?: number
  onSelect?(index: number): void
  label?: string
  onEndReached?(): void
  onActivate?(index: number): void
  getKey(item: T): Key
}

export function VirtualList<T>({
  items,
  rowHeight,
  renderRow,
  selectedIndex,
  onSelect,
  getKey,
  label,
  onEndReached,
  onActivate,
}: VirtualListProps<T>) {
  const id = useId()
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
  const safeTop = Math.min(viewport.top, Math.max(0, items.length * rowHeight - viewport.height))
  const start = Math.max(0, Math.floor(safeTop / rowHeight) - 3)
  const end = Math.min(items.length, start + Math.ceil(viewport.height / rowHeight) + 6)
  return (
    <div
      ref={ref}
      className={styles.viewport}
      style={
        !label && !onSelect
          ? { height: Math.min(items.length * rowHeight, 280), flex: 'none' }
          : undefined
      }
      role={label ? 'listbox' : undefined}
      aria-label={label}
      aria-activedescendant={
        label && selectedIndex !== undefined && selectedIndex >= start && selectedIndex < end
          ? `${id}-${selectedIndex}`
          : undefined
      }
      tabIndex={onSelect || onActivate ? 0 : undefined}
      onScroll={(event) => {
        const element = event.currentTarget
        if (element.scrollTop + element.clientHeight >= element.scrollHeight - rowHeight * 3)
          onEndReached?.()
        setViewport({
          top: event.currentTarget.scrollTop,
          height: event.currentTarget.clientHeight || 400,
        })
      }}
      onKeyDown={(event) => {
        if (!items.length) return
        const index = Math.max(0, Math.min(items.length - 1, selectedIndex ?? 0))
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.stopPropagation()
          event.preventDefault()
          // Preserve focus navigation for embedded buttons and sidebar options.
          const row = (event.target as HTMLElement).closest<HTMLElement>('[data-virtual-index]')
          if (row) {
            let next = Math.max(
              0,
              Math.min(
                items.length - 1,
                Number(row.dataset.virtualIndex) + (event.key === 'ArrowDown' ? 1 : -1)
              )
            )
            const direction = event.key === 'ArrowDown' ? 1 : -1
            const controlAt = (position: number) =>
              ref.current?.querySelector<HTMLElement>(
                `[data-virtual-index="${position}"] button:not(:disabled), [data-virtual-index="${position}"] [role="option"]`
              )
            // Group headings are rows, but must not interrupt keyboard traversal.
            while (
              next >= 0 &&
              next < items.length &&
              ref.current?.querySelector(`[data-virtual-index="${next}"]`) &&
              !controlAt(next)
            )
              next += direction
            if (next < 0 || next >= items.length) return
            const top = next * rowHeight
            if (
              top < event.currentTarget.scrollTop ||
              top + rowHeight >
                event.currentTarget.scrollTop + (event.currentTarget.clientHeight || 400)
            ) {
              event.currentTarget.scrollTop = top
              setViewport({ top, height: event.currentTarget.clientHeight || 400 })
            }
            onSelect?.(next)
            const focus = () => controlAt(next)?.focus()
            if (ref.current?.querySelector(`[data-virtual-index="${next}"]`)) focus()
            else requestAnimationFrame(focus)
            return
          }
          if (!onSelect) return
          event.currentTarget.focus()
          onSelect(
            Math.max(
              0,
              Math.min(
                items.length - 1,
                (selectedIndex ?? -1) + (event.key === 'ArrowDown' ? 1 : -1)
              )
            )
          )
        } else if (
          event.target === event.currentTarget &&
          (event.key === 'Enter' || event.key === ' ')
        ) {
          event.preventDefault()
          if (onActivate) onActivate(index)
          else onSelect?.(index)
        }
      }}
    >
      <div className={styles.content} style={{ height: items.length * rowHeight }}>
        {items.slice(start, end).map((item, offset) => (
          <div
            key={getKey(item)}
            id={`${id}-${start + offset}`}
            data-virtual-index={start + offset}
            role={label ? 'option' : undefined}
            aria-selected={label ? start + offset === selectedIndex : undefined}
            aria-posinset={label ? start + offset + 1 : undefined}
            aria-setsize={label ? items.length : undefined}
            onClick={
              label
                ? () => {
                    ref.current?.focus()
                    onSelect?.(start + offset)
                  }
                : undefined
            }
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
