import { useState, type ReactNode } from 'react'
import { useT } from '../../i18n'
import styles from './HistoryView.module.css'

const key = 'ghp.history.splitWidth'
const clamp = (value: number) => Math.max(25, Math.min(75, value))
/** Temporary implementation until U1's common SplitPane is available. */
export function SplitPane({ left, right }: { left: ReactNode; right: ReactNode }) {
  const t = useT()
  const [width, setWidth] = useState(() => {
    try {
      const value = Number(localStorage.getItem(key))
      return value && Number.isFinite(value) ? clamp(value) : 48
    } catch {
      return 48
    }
  })
  const update = (value: number) => {
    const next = clamp(value)
    setWidth(next)
    try {
      localStorage.setItem(key, String(next))
    } catch {
      /* Storage is optional. */
    }
  }
  return (
    <div
      className={styles.split}
      style={{
        gridTemplateColumns: `minmax(0, ${width}fr) var(--space-2) minmax(0, ${100 - width}fr)`,
      }}
    >
      {left}
      <div
        role="separator"
        aria-label={t('historyView.resize')}
        aria-orientation="vertical"
        aria-valuemin={25}
        aria-valuemax={75}
        aria-valuenow={Math.round(width)}
        tabIndex={0}
        className={styles.separator}
        onKeyDown={(event) => {
          if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
            event.preventDefault()
            update(width + (event.key === 'ArrowLeft' ? -2 : 2))
          }
        }}
        onPointerDown={(event) => event.currentTarget.setPointerCapture(event.pointerId)}
        onPointerMove={(event) => {
          if (!event.currentTarget.hasPointerCapture(event.pointerId)) return
          const rect = event.currentTarget.parentElement!.getBoundingClientRect()
          if (rect.width) update(((event.clientX - rect.left) / rect.width) * 100)
        }}
        onPointerUp={(event) => {
          if (event.currentTarget.hasPointerCapture(event.pointerId))
            event.currentTarget.releasePointerCapture(event.pointerId)
        }}
      />
      {right}
    </div>
  )
}
