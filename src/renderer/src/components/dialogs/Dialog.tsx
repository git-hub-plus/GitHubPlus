import { useEffect, useId, useRef, type ReactNode } from 'react'
import { useT } from '../../i18n'
import styles from './Dialog.module.css'

export function Dialog({
  title,
  children,
  onClose,
  onSubmit,
  submitLabel,
  busy = false,
  disabled = false,
}: {
  title: string
  children: ReactNode
  onClose(): void
  onSubmit?(): void
  submitLabel?: string
  busy?: boolean
  disabled?: boolean
}) {
  const t = useT()
  const ref = useRef<HTMLDialogElement>(null)
  const heading = useId()
  useEffect(() => {
    const dialog = ref.current!
    const previous = document.activeElement as HTMLElement | null
    dialog.showModal()
    dialog.querySelector<HTMLInputElement>('input:not([type="checkbox"])')?.focus()
    return () => {
      dialog.close()
      previous?.focus()
    }
  }, [])
  return (
    <dialog
      ref={ref}
      className={styles.dialog}
      aria-labelledby={heading}
      onCancel={(event) => {
        event.preventDefault()
        if (!busy) onClose()
      }}
    >
      <form
        onSubmit={(event) => {
          event.preventDefault()
          if (!busy && !disabled) onSubmit?.()
        }}
      >
        <h2 id={heading}>{title}</h2>
        <div className={styles.body}>{children}</div>
        <footer>
          <button type="button" disabled={busy} onClick={onClose}>
            {t('common.close')}
          </button>
          {onSubmit && (
            <button type="submit" disabled={busy || disabled}>
              {busy ? t('common.loading') : (submitLabel ?? t('common.ok'))}
            </button>
          )}
        </footer>
      </form>
    </dialog>
  )
}
