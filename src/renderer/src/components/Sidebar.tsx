import { useMemo, useState } from 'react'
import type { RepositoryGroup, RepositoryInfo } from '@shared/models/app'
import { useAppStore } from '../state/app-store'
import { useT } from '../i18n'
import styles from './Sidebar.module.css'

const groupOrder: ReadonlyArray<RepositoryGroup> = ['local', 'hub', 'github']

function displayName(repo: RepositoryInfo): string {
  return repo.alias ?? repo.name
}

/** Always-visible repository list grouped by where the main remote lives. */
export function Sidebar() {
  const t = useT()
  const repositories = useAppStore((s) => s.repositories)
  const selectedId = useAppStore((s) => s.selectedRepositoryId)
  const selectRepository = useAppStore((s) => s.selectRepository)
  const [filter, setFilter] = useState('')

  const groups = useMemo(() => {
    const query = filter.trim().toLowerCase()
    const visible = repositories
      .filter((r) => !query || displayName(r).toLowerCase().includes(query))
      .toSorted(
        (a, b) =>
          Number(b.pinned) - Number(a.pinned) || displayName(a).localeCompare(displayName(b))
      )
    return groupOrder
      .map((group) => ({ group, items: visible.filter((r) => r.group === group) }))
      .filter((g) => g.items.length > 0)
  }, [repositories, filter])

  return (
    <nav className={styles.sidebar} aria-label={t('sidebar.title')}>
      <div className={styles.header}>
        <input
          className={styles.filter}
          type="search"
          value={filter}
          placeholder={t('sidebar.filterPlaceholder')}
          aria-label={t('sidebar.filterPlaceholder')}
          onChange={(e) => setFilter(e.target.value)}
        />
      </div>
      <div className={styles.list}>
        {repositories.length === 0 && <p className={styles.empty}>{t('sidebar.empty')}</p>}
        {groups.map(({ group, items }) => (
          <section key={group} className={styles.group}>
            <h2 className={styles.groupTitle}>{t(`sidebar.groups.${group}`)}</h2>
            <ul role="listbox" aria-label={t(`sidebar.groups.${group}`)}>
              {items.map((repo) => (
                <li
                  key={repo.id}
                  role="option"
                  aria-selected={repo.id === selectedId}
                  className={styles.item}
                  data-unavailable={!repo.available || undefined}
                  title={repo.path}
                  onClick={() => void selectRepository(repo.id)}
                >
                  <span className={styles.name}>{displayName(repo)}</span>
                  {!repo.available && (
                    <span className={styles.badge}>{t('sidebar.unavailable')}</span>
                  )}
                </li>
              ))}
            </ul>
          </section>
        ))}
      </div>
    </nav>
  )
}
