import { useAppStore, useSelectedRepository, type WorkspaceTab } from '../state/app-store'
import { useT } from '../i18n'
import styles from './Workspace.module.css'

const tabs: ReadonlyArray<WorkspaceTab> = ['changes', 'history']

/** Changes / History tabs for the selected repository (contents land in N2). */
export function Workspace() {
  const t = useT()
  const repository = useSelectedRepository()
  const tab = useAppStore((s) => s.tab)
  const setTab = useAppStore((s) => s.setTab)

  if (!repository) {
    return <main className={styles.empty}>{t('workspace.noRepository')}</main>
  }

  return (
    <main className={styles.workspace}>
      <div className={styles.tabs} role="tablist">
        {tabs.map((id) => (
          <button
            key={id}
            role="tab"
            aria-selected={tab === id}
            className={styles.tab}
            onClick={() => setTab(id)}
          >
            {t(`workspace.${id}`)}
          </button>
        ))}
      </div>
      <section className={styles.panel} role="tabpanel" aria-label={t(`workspace.${tab}`)} />
    </main>
  )
}
