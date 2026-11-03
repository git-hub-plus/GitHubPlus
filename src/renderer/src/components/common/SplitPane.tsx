import { useRef, useState, type ReactNode } from 'react'
import { t } from '@shared/i18n'
import styles from './SplitPane.module.css'

export function SplitPane({
  left,
  right,
  storageKey = 'ghp.changesPanelWidth',
  unit = 'px',
  defaultSize = unit === 'percent' ? 48 : 320,
  minSize = unit === 'percent' ? 25 : 240,
}: {
  left: ReactNode
  right: ReactNode
  storageKey?: string
  defaultSize?: number
  minSize?: number
  unit?: 'px' | 'percent'
}) {
  const ref = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(() => {
    try {
      const value = Number(localStorage.getItem(storageKey))
      return Number.isFinite(value) &&
        value >= minSize &&
        (unit !== 'percent' || value <= 100 - minSize)
        ? value
        : defaultSize
    } catch {
      return defaultSize
    }
  })
  const update = (value: number) => {
    const next = Math.max(
      minSize,
      Math.min(
        value,
        unit === 'percent'
          ? 100 - minSize
          : Math.max(minSize, (ref.current?.clientWidth || 1000) - 160)
      )
    )
    setWidth(next)
    try {
      localStorage.setItem(storageKey, String(next))
    } catch {
      /* Storage may be unavailable. */
    }
  }
  return (
    <div ref={ref} className={styles.split}>
      <div className={styles.left} style={{ width: `${width}${unit === 'percent' ? '%' : 'px'}` }}>
        {left}
      </div>
      <div
        role="separator"
        aria-label={t(unit === 'percent' ? 'historyView.resize' : 'changesView.resize')}
        aria-orientation="vertical"
        aria-valuenow={width}
        aria-valuemin={minSize}
        aria-valuemax={unit === 'percent' ? 100 - minSize : undefined}
        tabIndex={0}
        className={styles.separator}
        onKeyDown={(event) => {
          if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
            event.preventDefault()
            update(width + (event.key === 'ArrowLeft' ? -1 : 1) * (unit === 'percent' ? 2 : 16))
          }
        }}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId)
        }}
        onPointerMove={(event) => {
          if (event.currentTarget.hasPointerCapture(event.pointerId)) {
            const rect = ref.current!.getBoundingClientRect()
            const pixels = event.clientX - rect.left
            if (unit === 'px' || rect.width)
              update(unit === 'percent' ? (pixels / rect.width) * 100 : pixels)
          }
        }}
        onPointerUp={(event) => {
          if (event.currentTarget.hasPointerCapture(event.pointerId))
            event.currentTarget.releasePointerCapture(event.pointerId)
        }}
      />
      <div className={styles.right}>{right}</div>
    </div>
  )
}
