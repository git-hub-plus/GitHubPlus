import { useSelectedRepository } from '../state/app-store'
import { useT } from '../i18n'
import styles from './Toolbar.module.css'

/**
 * Actions for the selected repository only: branch, sync, hub status.
 * Branch and sync wiring arrives with the git layer (N1/N2).
 */
export function Toolbar() {
  const t = useT()
  const repository = useSelectedRepository()

  return (
    <header className={styles.toolbar}>
      <button className={styles.branch} disabled={!repository} title={t('toolbar.branch')}>
        <span className={styles.label}>{t('toolbar.branch')}</span>
        <span>{t('toolbar.noBranch')}</span>
      </button>
      <div className={styles.spacer} />
      <button className={styles.action} disabled={!repository}>
        {t('toolbar.fetch')}
      </button>
    </header>
  )
}
