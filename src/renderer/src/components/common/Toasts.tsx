import { dismissToast, useToastStore } from '../../state/toast-store'
import { useT } from '../../i18n'
import styles from '../toolbar/Actions.module.css'

export function Toasts() {
  const t = useT()
  const toasts = useToastStore((s) => s.toasts)
  return (
    <aside className={styles.toasts} aria-label={t('repoActions.notifications')} aria-live="polite">
      {toasts.map((toast) => (
        <div
          key={toast.id}
          className={styles.toast}
          role={toast.kind === 'error' ? 'alert' : 'status'}
        >
          <p>{t(toast.message)}</p>
          {toast.detail && (
            <details>
              <summary>{t('common.details')}</summary>
              <pre>{toast.detail}</pre>
            </details>
          )}
          <button onClick={() => dismissToast(toast.id)}>{t('common.close')}</button>
        </div>
      ))}
    </aside>
  )
}
