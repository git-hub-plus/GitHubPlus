import { useRef, useState, type ReactNode } from 'react'
import { t } from '@shared/i18n'
import styles from './Controls.module.css'

export function SplitPane({ left, right }: { left: ReactNode; right: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const [width, setWidth] = useState(() => {
    try {
      const value = Number(localStorage.getItem('ghp.changesPanelWidth'))
      return Number.isFinite(value) && value >= 240 ? value : 320
    } catch {
      return 320
    }
  })
  const update = (value: number) => {
    const next = Math.max(
      240,
      Math.min(value, Math.max(240, (ref.current?.clientWidth || 1000) - 160))
    )
    setWidth(next)
    try {
      localStorage.setItem('ghp.changesPanelWidth', String(next))
    } catch {
      /* Storage may be unavailable. */
    }
  }
  return (
    <div ref={ref} className={styles.split}>
      <div className={styles.left} style={{ width }}>
        {left}
      </div>
      <div
        role="separator"
        aria-label={t('changesView.resize')}
        aria-orientation="vertical"
        aria-valuenow={width}
        aria-valuemin={240}
        tabIndex={0}
        className={styles.separator}
        onKeyDown={(event) => {
          if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
            event.preventDefault()
            update(width + (event.key === 'ArrowLeft' ? -16 : 16))
          }
        }}
        onPointerDown={(event) => {
          event.currentTarget.setPointerCapture(event.pointerId)
        }}
        onPointerMove={(event) => {
          if (event.currentTarget.hasPointerCapture(event.pointerId))
            update(event.clientX - (ref.current?.getBoundingClientRect().left ?? 0))
        }}
        onPointerUp={(event) => event.currentTarget.releasePointerCapture(event.pointerId)}
      />
      <div className={styles.right}>{right}</div>
    </div>
  )
}
