import { useCallback, useMemo, useState } from 'react'
import type { RepositoryGroup, RepositoryInfo } from '@shared/models/app'
import { useAppStore } from '../state/app-store'
import { useT } from '../i18n'
import styles from './Sidebar.module.css'
import { useDialogStore } from '../state/dialog-store'
import { useRepoStore } from '../state/repo-store'
import { showToast } from '../state/toast-store'
import { invoke } from '../ipc'
import { Popover } from './common/Popover'
import { Dialog } from './dialogs/Dialog'
import { VirtualList } from './toolbar/VirtualList'
import { HubGroupMenu } from './hub/HubGroupMenu'
import { useHubStore } from '../state/hub-store'

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
  const [addOpen, setAddOpen] = useState(false)
  const [context, setContext] = useState<RepositoryInfo>()
  const [edit, setEdit] = useState<'alias' | 'remove'>()
  const [alias, setAlias] = useState('')
  const [busy, setBusy] = useState(false)
  const status = useRepoStore((s) => (s.repoId === selectedId ? s.status : undefined))
  const closeAdd = useCallback(() => setAddOpen(false), [])
  const closeContext = useCallback(() => {
    setContext(undefined)
    setEdit(undefined)
  }, [])
  const updateContext = async () => {
    if (!context) return
    setBusy(true)
    try {
      if (edit === 'remove') {
        await invoke('repos:remove', context.id)
        useAppStore.setState((s) => ({
          repositories: s.repositories.filter((r) => r.id !== context.id),
          selectedRepositoryId:
            s.selectedRepositoryId === context.id ? undefined : s.selectedRepositoryId,
        }))
      } else {
        const updated = await invoke(
          'repos:update',
          context.id,
          edit === 'alias' ? { alias: alias.trim() || null } : { pinned: !context.pinned }
        )
        useAppStore.setState((s) => ({
          repositories: s.repositories.map((r) => (r.id === updated.id ? updated : r)),
        }))
      }
      closeContext()
      showToast()
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }

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
      .filter((g) => g.group === 'hub' || g.items.length > 0)
  }, [repositories, filter])

  return (
    <nav className={styles.sidebar} aria-label={t('sidebar.title')}>
      <div className={styles.header}>
        <button onClick={() => setAddOpen(!addOpen)} aria-expanded={addOpen}>
          {t('repoActions.add')}
        </button>
        {addOpen && (
          <Popover label={t('repoActions.add')} onClose={closeAdd}>
            {(['add', 'create', 'clone'] as const).map((kind) => (
              <button
                key={kind}
                onClick={() => {
                  useDialogStore.getState().open(kind)
                  closeAdd()
                }}
              >
                {t(`repoActions.dialogs.${kind}`)}
              </button>
            ))}
          </Popover>
        )}
        <input
          id="repository-search"
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
            {group === 'hub' ? (
              <HubGroupMenu titleClassName={styles.groupTitle} />
            ) : (
              <h2 className={styles.groupTitle}>{t(`sidebar.groups.${group}`)}</h2>
            )}
            <div role="listbox" aria-label={t(`sidebar.groups.${group}`)}>
              <VirtualList
                key={filter}
                items={items}
                rowHeight={28}
                getKey={(repo) => repo.id}
                renderRow={(repo) => (
                  <div
                    key={repo.id}
                    role="option"
                    aria-selected={repo.id === selectedId}
                    className={styles.item}
                    data-unavailable={!repo.available || undefined}
                    title={repo.path}
                    tabIndex={
                      repo.id === selectedId || (!selectedId && repo === groups[0]?.items[0])
                        ? 0
                        : -1
                    }
                    onClick={() => void selectRepository(repo.id).catch(showToast)}
                    onContextMenu={(event) => {
                      event.preventDefault()
                      setContext(repo)
                    }}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' || event.key === ' ') {
                        event.preventDefault()
                        void selectRepository(repo.id).catch(showToast)
                      } else if (
                        event.key === 'ContextMenu' ||
                        (event.shiftKey && event.key === 'F10')
                      ) {
                        event.preventDefault()
                        setContext(repo)
                      } else if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
                        event.preventDefault()
                        const rows = [
                          ...event.currentTarget
                            .closest('nav')!
                            .querySelectorAll<HTMLElement>('[role="option"]'),
                        ]
                        rows[
                          (rows.indexOf(event.currentTarget) +
                            (event.key === 'ArrowDown' ? 1 : -1) +
                            rows.length) %
                            rows.length
                        ]?.focus()
                      }
                    }}
                  >
                    <span className={styles.name}>{displayName(repo)}</span>
                    {repo.id === selectedId && status && (
                      <span
                        className={styles.badge}
                        aria-label={t('repoActions.repoStatus', {
                          changes: status.files.length,
                          ahead: status.ahead,
                          behind: status.behind,
                        })}
                      >
                        {status.files.length > 0 && <span className={styles.dot} />}
                        {status.ahead > 0 && t('repoActions.ahead', { count: status.ahead })}
                        {status.behind > 0 && t('repoActions.behind', { count: status.behind })}
                      </span>
                    )}
                    {!repo.available && (
                      <span className={styles.badge}>{t('sidebar.unavailable')}</span>
                    )}
                  </div>
                )}
              />
            </div>
          </section>
        ))}
      </div>
      {context && !edit && (
        <Popover label={displayName(context)} onClose={closeContext}>
          <button
            onClick={() => {
              useHubStore.getState().open('publish', context.id)
              closeContext()
            }}
          >
            {t('hub.publish')}
          </button>
          <button
            onClick={() => {
              setAlias(context.alias ?? context.name)
              setEdit('alias')
            }}
          >
            {t('repoActions.alias')}
          </button>
          <button disabled={busy} onClick={() => void updateContext()}>
            {t(context.pinned ? 'repoActions.unpin' : 'repoActions.pin')}
          </button>
          <button onClick={() => setEdit('remove')}>{t('repoActions.remove')}</button>
        </Popover>
      )}
      {context && edit && (
        <Dialog
          title={t(edit === 'alias' ? 'repoActions.alias' : 'repoActions.remove')}
          onClose={closeContext}
          onSubmit={() => void updateContext()}
          busy={busy}
        >
          {edit === 'alias' ? (
            <label>
              {t('repoActions.name')}
              <input value={alias} onChange={(event) => setAlias(event.target.value)} />
            </label>
          ) : (
            <p>{t('repoActions.confirmRemove', { name: displayName(context) })}</p>
          )}
        </Dialog>
      )}
    </nav>
  )
}
