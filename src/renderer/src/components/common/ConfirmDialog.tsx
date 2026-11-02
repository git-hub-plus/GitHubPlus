import { useEffect, useRef, useId } from 'react'
import { t } from '@shared/i18n'
import styles from './Controls.module.css'

export function ConfirmDialog({
  message,
  onConfirm,
  onCancel,
}: {
  message: string
  onConfirm(): void
  onCancel(): void
}) {
  const ref = useRef<HTMLDivElement>(null)
  const id = useId()
  useEffect(() => {
    const previous = document.activeElement as HTMLElement | null
    ref.current?.querySelector('button')?.focus()
    return () => previous?.focus()
  }, [])
  return (
    <div
      className={styles.backdrop}
      onClick={(event) => {
        if (event.target === event.currentTarget) onCancel()
      }}
    >
      <div
        ref={ref}
        role="alertdialog"
        aria-modal="true"
        aria-labelledby={id}
        className={styles.dialog}
        onKeyDown={(event) => {
          if (event.key === 'Escape') onCancel()
          if (event.key === 'Tab') {
            const buttons = [...event.currentTarget.querySelectorAll('button')]
            event.preventDefault()
            buttons[
              (buttons.indexOf(document.activeElement as HTMLButtonElement) + 1) % buttons.length
            ]?.focus()
          }
        }}
      >
        <p id={id}>{message}</p>
        <div className={styles.actions}>
          <button onClick={onCancel}>{t('changesView.cancel')}</button>
          <button onClick={onConfirm}>{t('changesView.discardConfirm')}</button>
        </div>
      </div>
    </div>
  )
}
