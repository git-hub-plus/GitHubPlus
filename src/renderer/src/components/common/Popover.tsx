import { useEffect, useRef, type ReactNode } from 'react'
import styles from '../toolbar/Actions.module.css'

export function Popover({
  children,
  onClose,
  label,
}: {
  children: ReactNode
  onClose(): void
  label: string
}) {
  const ref = useRef<HTMLDivElement>(null)
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    ref.current?.querySelector<HTMLElement>('input, button')?.focus()
    const outside = (event: PointerEvent) => {
      if ((event.target as Element).closest('dialog[open]')) return
      if (!ref.current?.contains(event.target as Node)) onClose()
    }
    document.addEventListener('pointerdown', outside)
    return () => {
      document.removeEventListener('pointerdown', outside)
      previous?.focus()
    }
  }, [onClose])
  return (
    <div
      ref={ref}
      className={styles.popover}
      role="dialog"
      aria-label={label}
      onKeyDown={(event) => {
        if (event.key === 'Escape') {
          event.stopPropagation()
          onClose()
        }
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault()
          const controls = [
            ...event.currentTarget.querySelectorAll<HTMLElement>('input, button:not(:disabled)'),
          ]
          const index = controls.indexOf(document.activeElement as HTMLElement)
          controls[
            (index + (event.key === 'ArrowDown' ? 1 : -1) + controls.length) % controls.length
          ]?.focus()
        }
      }}
    >
      {children}
    </div>
  )
}
