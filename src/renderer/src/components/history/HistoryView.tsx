import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react'
import { getLocale } from '@shared/i18n'
import { useAppStore } from '../../state/app-store'
import { useHistoryStore } from '../../state/history-store'
import { subscribe } from '../../ipc'
import { useT } from '../../i18n'
import { relativeTime } from '../../lib/relative-time'
import type { GraphRow } from '../../lib/commit-graph'
import { DiffView } from '../diff/DiffView'
import { VirtualList } from '../common/VirtualList'
import { SplitPane } from '../common/SplitPane'
import { useHistoryActions } from '../history-actions/useHistoryActions'
import styles from './HistoryView.module.css'

function badgeKeyDown(event: KeyboardEvent<HTMLElement>) {
  if (
    event.key === 'Enter' ||
    event.key === ' ' ||
    event.key === 'ContextMenu' ||
    (event.shiftKey && event.key === 'F10')
  ) {
    event.preventDefault()
    event.stopPropagation()
    const bounds = event.currentTarget.getBoundingClientRect()
    event.currentTarget.dispatchEvent(
      new MouseEvent('contextmenu', { bubbles: true, clientX: bounds.left, clientY: bounds.bottom })
    )
  }
}

function Graph({ row, width }: { row: GraphRow; width: number }) {
  const x = (lane: number) => lane * 12 + 10
  return (
    <svg aria-hidden="true" width={width * 12 + 12} height={28} className={styles.graph}>
      {row.edges.map((edge, index) => {
        const start = edge.type === 'incoming' || edge.type === 'continue' ? 0 : 14
        const end = edge.type === 'incoming' ? 14 : 28
        return (
          <path
            key={index}
            d={`M ${x(edge.fromLane)} ${start} C ${x(edge.fromLane)} ${(start + end) / 2}, ${x(edge.toLane)} ${(start + end) / 2}, ${x(edge.toLane)} ${end}`}
            fill="none"
            stroke={`var(--graph-${edge.color + 1})`}
            strokeWidth={1.5}
          />
        )
      })}
      <circle cx={x(row.lane)} cy={14} r={3.5} fill={`var(--graph-${row.color + 1})`} />
    </svg>
  )
}

export function HistoryView() {
  const repoId = useAppStore((state) => state.selectedRepositoryId)
  return <RepositoryHistory key={repoId ?? ''} />
}

function RepositoryHistory() {
  const t = useT()
  const repoId = useAppStore((state) => state.selectedRepositoryId)
  const state = useHistoryStore()
  const actions = useHistoryActions(repoId)
  const detailRef = useRef<HTMLElement>(null)
  const [copyState, setCopyState] = useState<'copied' | 'copyFailed' | undefined>()
  useEffect(() => {
    useHistoryStore.getState().reset(repoId)
    void useHistoryStore.getState().load()
    const unsubscribe = subscribe('git:repoChanged', (event) => {
      if (event.repoId === repoId) void useHistoryStore.getState().load(true)
    })
    return () => {
      unsubscribe()
      useHistoryStore.getState().reset()
    }
  }, [repoId])
  const visible = useMemo(() => {
    const search = state.search.toLocaleLowerCase(getLocale())
    return state.commits
      .map((commit, index) => ({ commit, row: state.rows[index] }))
      .filter(({ commit }) =>
        `${commit.summary} ${commit.author.name}`.toLocaleLowerCase(getLocale()).includes(search)
      )
  }, [state.commits, state.rows, state.search])
  const graphWidth = state.rows.reduce((width, row) => Math.max(width, row.width), 1)
  const selected = state.commits.find((commit) => commit.sha === state.selectedSha)
  const selectedIndex = visible.findIndex(({ commit }) => commit.sha === state.selectedSha)
  const errorKey =
    state.error?.kind === 'not-a-repository'
      ? 'historyView.notRepository'
      : state.error?.kind === 'not-found'
        ? 'historyView.notFound'
        : state.error?.kind === 'network'
          ? 'historyView.network'
          : state.error?.kind === 'authentication-failed'
            ? 'historyView.authentication'
            : 'historyView.failed'
  if (!repoId) return <div className={styles.message}>{t('historyView.noRepository')}</div>
  return (
    <div className={styles.history}>
      {actions.ui}
      {state.error && (
        <div role="alert" className={styles.error}>
          {t(errorKey)} <button onClick={() => void state.load(true)}>{t('common.retry')}</button>
          <details>
            <summary>{t('common.details')}</summary>
            <pre>{state.error.detail ?? state.error.message}</pre>
          </details>
        </div>
      )}
      <SplitPane
        storageKey="ghp.history.splitWidth"
        defaultSize={48}
        minSize={25}
        unit="percent"
        left={
          <section className={styles.list} aria-label={t('historyView.title')}>
            <div className={styles.filters}>
              <select
                aria-label={t('historyView.branchFilter')}
                value={state.all ? 'all' : 'current'}
                onChange={(event) => state.setAll(event.target.value === 'all')}
              >
                <option value="all">{t('historyView.allBranches')}</option>
                <option value="current">{t('historyView.currentBranch')}</option>
              </select>
              <input
                type="search"
                aria-label={t('historyView.search')}
                placeholder={t('historyView.search')}
                value={state.search}
                onChange={(event) => state.setSearch(event.target.value)}
              />
            </div>
            <div
              className={styles.commitList}
              onKeyDownCapture={(event) => {
                if ((event.target as HTMLElement).closest('[data-history-badge]')) return
                if (event.key === 'ContextMenu' || (event.shiftKey && event.key === 'F10')) {
                  const row = event.currentTarget.querySelector<HTMLElement>(
                    `[data-sha="${state.selectedSha}"]`
                  )
                  row?.dispatchEvent(
                    new MouseEvent('contextmenu', {
                      bubbles: true,
                      clientX: row.getBoundingClientRect().left,
                      clientY: row.getBoundingClientRect().bottom,
                    })
                  )
                  event.preventDefault()
                }
                if (event.shiftKey && (event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
                  event.preventDefault()
                  event.stopPropagation()
                  const next =
                    visible[
                      Math.max(
                        0,
                        Math.min(
                          visible.length - 1,
                          selectedIndex + (event.key === 'ArrowDown' ? 1 : -1)
                        )
                      )
                    ]
                  if (next)
                    state.choose(
                      next.commit.sha,
                      { range: true },
                      visible.map(({ commit }) => commit.sha)
                    )
                }
              }}
            >
              <VirtualList
                items={visible}
                rowHeight={28}
                selectedIndex={selectedIndex}
                label={t('historyView.commits')}
                getKey={({ commit }) => commit.sha}
                onSelect={(index) => {
                  setCopyState(undefined)
                  state.choose(visible[index].commit.sha)
                }}
                onActivate={() => detailRef.current?.focus()}
                onEndReached={() => void state.load()}
                renderRow={({ commit, row }) => (
                  <div
                    className={`${styles.commitRow} ${state.selectedShas.includes(commit.sha) ? styles.multiSelected : ''}`}
                    data-sha={commit.sha}
                    draggable={actions.canDrag(commit.sha)}
                    onDragStart={(event) => {
                      actions.dragStart(commit.sha)
                      event.dataTransfer?.setData('text/plain', commit.sha)
                    }}
                    onDragEnd={actions.dragEnd}
                    onDragOver={(event) => event.preventDefault()}
                    onDrop={(event) => {
                      event.preventDefault()
                      actions.drop(commit.sha)
                    }}
                    onContextMenu={(event) => actions.commitMenu(event, commit)}
                    onClick={(event) => {
                      event.stopPropagation()
                      const listbox = event.currentTarget.closest<HTMLElement>('[role="listbox"]')
                      listbox?.focus()
                      state.choose(
                        commit.sha,
                        { toggle: event.ctrlKey || event.metaKey, range: event.shiftKey },
                        visible.map(({ commit }) => commit.sha)
                      )
                    }}
                  >
                    <input
                      type="checkbox"
                      aria-label={t('historyActions.selectCommit', { summary: commit.summary })}
                      checked={state.selectedShas.includes(commit.sha)}
                      onClick={(event) => event.stopPropagation()}
                      onChange={() => state.choose(commit.sha, { toggle: true })}
                    />
                    <Graph row={row} width={graphWidth} />
                    <span className={styles.summary} title={commit.summary}>
                      {commit.summary}
                    </span>
                    <span className={styles.badges}>
                      {state.branches
                        .filter((branch) => branch.tipSha === commit.sha)
                        .map((branch) => (
                          <span
                            data-history-badge
                            role="button"
                            tabIndex={0}
                            aria-haspopup="menu"
                            aria-label={t('historyActions.branchBadge', { name: branch.name })}
                            onKeyDown={badgeKeyDown}
                            onClick={actions.rebaseMenu}
                            onContextMenu={actions.rebaseMenu}
                            key={`${branch.type}:${branch.name}`}
                            className={branch.isCurrent ? styles.currentBadge : styles.badge}
                            title={branch.isCurrent ? t('historyView.currentBranch') : branch.name}
                          >
                            {branch.name}
                          </span>
                        ))}
                      {commit.tags.map((tag) => (
                        <span
                          data-history-badge
                          role="button"
                          tabIndex={0}
                          aria-haspopup="menu"
                          aria-label={t('historyActions.tagBadge', { name: tag })}
                          onKeyDown={badgeKeyDown}
                          onClick={(event) => actions.tagMenu(event, tag)}
                          onContextMenu={(event) => actions.tagMenu(event, tag)}
                          key={tag}
                          className={styles.badge}
                          title={t('historyView.tag')}
                        >
                          {tag}
                        </span>
                      ))}
                    </span>
                    <span className={styles.author} title={commit.author.name}>
                      {commit.author.name}
                    </span>
                    <time
                      className={styles.time}
                      dateTime={new Date(commit.author.date).toISOString()}
                    >
                      {relativeTime(commit.author.date)}
                    </time>
                  </div>
                )}
              />
            </div>
            <div className={styles.actionBar}>
              <button disabled={!actions.canRebase} onClick={actions.rebase}>
                {t('historyActions.rebase')}
              </button>
              <span role="status">
                {t('historyActions.selected', { count: state.selectedShas.length })}
              </span>
              <button
                disabled={actions.busy}
                onClick={actions.moveOldest}
                onDragOver={(event) => event.preventDefault()}
                onDrop={(event) => {
                  event.preventDefault()
                  actions.drop(null)
                }}
              >
                {t('historyActions.oldest')}
              </button>
            </div>
            {!state.loading && visible.length === 0 && (
              <p className={styles.message}>
                {t(state.search ? 'historyView.noMatches' : 'historyView.empty')}
              </p>
            )}
            <div className={styles.footer} role="status">
              {state.loading
                ? t('common.loading')
                : t('historyView.loaded', { count: state.commits.length })}
              {state.hasMore && (
                <button disabled={state.loading} onClick={() => void state.load()}>
                  {t('historyView.loadMore')}
                </button>
              )}
            </div>
          </section>
        }
        right={
          <section
            ref={detailRef}
            tabIndex={-1}
            className={styles.detail}
            aria-label={t('historyView.details')}
          >
            {selected ? (
              <>
                <header className={styles.header}>
                  <h2>{selected.summary}</h2>
                  {selected.body && <p className={styles.body}>{selected.body}</p>}
                  <p>
                    {selected.author.name} &lt;{selected.author.email}&gt; ·{' '}
                    <time dateTime={new Date(selected.author.date).toISOString()}>
                      {new Intl.DateTimeFormat(getLocale(), {
                        dateStyle: 'medium',
                        timeStyle: 'short',
                      }).format(selected.author.date)}
                    </time>
                  </p>
                  <div className={styles.sha}>
                    <span>{t('historyView.sha')}</span> <code>{selected.sha}</code>
                    <button
                      onClick={async () => {
                        try {
                          await navigator.clipboard.writeText(selected.sha)
                          setCopyState('copied')
                        } catch {
                          setCopyState('copyFailed')
                        }
                      }}
                    >
                      {t('historyView.copy')}
                    </button>
                    <span role="status">{copyState && t(`historyView.${copyState}`)}</span>
                  </div>
                  <div className={styles.sha}>
                    <span>{t('historyView.parents')}</span>{' '}
                    {selected.parentShas.map((sha) => (
                      <code key={sha}>{sha}</code>
                    ))}
                  </div>
                </header>
                <div className={styles.files}>
                  <div className={styles.fileTitle}>
                    {t('historyView.files', { count: state.files.length })}
                  </div>
                  <VirtualList
                    items={state.files}
                    rowHeight={28}
                    getKey={(file) => file.path}
                    label={t('historyView.changedFiles')}
                    selectedIndex={state.files.findIndex((file) => file.path === state.path)}
                    onSelect={(index) => void state.selectFile(state.files[index].path)}
                    renderRow={(file) => (
                      <span className={styles.filePath} title={file.path}>
                        {file.path}
                      </span>
                    )}
                  />
                </div>
                {(state.detailLoading || state.diffLoading) && (
                  <p role="status" className={styles.message}>
                    {t('common.loading')}
                  </p>
                )}
                {!state.detailLoading && state.files.length === 0 && (
                  <p className={styles.message}>{t('historyView.noFiles')}</p>
                )}
                <div className={styles.diff}>
                  {state.diff && state.path && <DiffView diff={state.diff} path={state.path} />}
                </div>
              </>
            ) : (
              <p className={styles.message}>{t('historyView.choose')}</p>
            )}
          </section>
        }
      />
    </div>
  )
}
