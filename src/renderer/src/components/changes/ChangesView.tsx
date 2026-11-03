import { useCallback, useEffect, useRef, useState } from 'react'
import { t } from '@shared/i18n'
import { GhpError } from '@shared/errors'
import type { DiffSelectionData, FileDiff } from '@shared/models/diff'
import {
  getSelectionType,
  selectAll,
  selectNone,
  type SelectionType,
} from '@shared/models/diff-selection'
import type { WorkingFile } from '@shared/models/status'
import type { GitIdentity } from '@shared/ipc/git-advanced'
import { IdentityDialog } from '../dialogs/IdentityDialog'
import { invoke } from '../../ipc'
import { useAppStore } from '../../state/app-store'
import { useRepoStore } from '../../state/repo-store'
import { useChangesStore } from '../../state/changes-store'
import { VirtualList } from '../common/VirtualList'
import { SplitPane } from '../common/SplitPane'
import { ContextMenu } from '../common/ContextMenu'
import { ConfirmDialog } from '../common/ConfirmDialog'
import { DiffView } from '../diff/DiffView'
import styles from './ChangesView.module.css'

const emptyFiles: ReadonlyArray<WorkingFile> = []
function Checkbox({
  type,
  label,
  onChange,
  disabled,
}: {
  type: SelectionType
  label: string
  onChange(): void
  disabled?: boolean
}) {
  const ref = useRef<HTMLInputElement>(null)
  useEffect(() => {
    if (ref.current) ref.current.indeterminate = type === 'partial'
  }, [type])
  return (
    <input
      ref={ref}
      type="checkbox"
      aria-label={label}
      checked={type === 'all'}
      disabled={disabled}
      onChange={onChange}
    />
  )
}
function ErrorMessage({ error }: { error: unknown }) {
  const kind = error instanceof GhpError ? error.kind : 'internal'
  const key =
    kind === 'not-found' || kind === 'not-a-repository'
      ? 'changesView.errorMissing'
      : kind === 'merge-conflicts'
        ? 'changesView.errorConflict'
        : 'changesView.error'
  return (
    <div role="alert" className={styles.error}>
      <p>{t(key)}</p>
      <details>
        <summary>{t('changesView.details')}</summary>
        <pre>
          {error instanceof GhpError ? `${error.message}\n${error.detail ?? ''}` : String(error)}
        </pre>
      </details>
    </div>
  )
}
function FilePath({ path }: { path: string }) {
  const index = path.lastIndexOf('/') + 1
  return (
    <>
      <span className={styles.folder}>{path.slice(0, index)}</span>
      <strong>{path.slice(index)}</strong>
    </>
  )
}
function CommitForm({
  repoId,
  branch,
  files,
  selections,
}: {
  repoId: string
  branch?: string
  files: ReadonlyArray<WorkingFile>
  selections: Record<string, DiffSelectionData>
}) {
  const [summary, setSummary] = useState('')
  const [description, setDescription] = useState('')
  const [amend, setAmend] = useState(false)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>()
  const [identity, setIdentity] = useState<GitIdentity>()
  const pending = useRef(false)
  const included = files.filter(
    (file) => selections[file.path] && getSelectionType(selections[file.path]) !== 'none'
  )
  const disabled = busy || !summary.trim() || !included.length
  const commit = async (identitySaved = false) => {
    if (disabled || pending.current) return
    pending.current = true
    setBusy(true)
    setError(undefined)
    try {
      if (!identitySaved) {
        const current = await invoke('git:getIdentity', repoId)
        if (current.source === 'none') {
          setIdentity(current)
          return
        }
      }
      await invoke('git:commit', repoId, {
        summary: summary.trim(),
        description,
        files: included.map(({ path }) => ({ path, selection: selections[path] })),
        amend,
      })
      setSummary('')
      setDescription('')
      setAmend(false)
      await useRepoStore.getState().refresh()
    } catch (failure) {
      if (
        failure instanceof GhpError &&
        /Author identity unknown|Please tell me who you are/i.test(
          `${failure.message} ${failure.detail ?? ''}`
        )
      )
        setIdentity({ source: 'none' })
      else setError(failure)
    } finally {
      setBusy(false)
      pending.current = false
    }
  }
  return (
    <>
      {identity && (
        <IdentityDialog
          repoId={repoId}
          identity={identity}
          onClose={() => setIdentity(undefined)}
          onSaved={() => {
            setIdentity(undefined)
            void commit(true)
          }}
        />
      )}
      <form
        className={styles.commit}
        onSubmit={(event) => {
          event.preventDefault()
          void commit()
        }}
        onKeyDown={(event) => {
          if (event.ctrlKey && event.key === 'Enter') {
            event.preventDefault()
            void commit()
          }
        }}
      >
        <label htmlFor="commit-summary">{t('changesView.summary')}</label>
        <input
          id="commit-summary"
          required
          value={summary}
          disabled={busy}
          onChange={(event) => setSummary(event.target.value)}
          aria-describedby={summary.length > 72 ? 'summary-warning' : undefined}
        />
        {summary.length > 72 && (
          <span id="summary-warning" className={styles.warning}>
            {t('changesView.summaryWarning', { count: summary.length })}
          </span>
        )}
        <label htmlFor="commit-description">{t('changesView.description')}</label>
        <textarea
          id="commit-description"
          rows={4}
          value={description}
          disabled={busy}
          onChange={(event) => setDescription(event.target.value)}
        />
        <label className={styles.amend}>
          <input
            type="checkbox"
            checked={amend}
            disabled={busy}
            onChange={(event) => setAmend(event.target.checked)}
          />
          {t('changesView.amend')}
        </label>
        <button type="submit" disabled={disabled} className={styles.commitButton}>
          {busy
            ? t('changesView.committing')
            : t('changesView.commit', { branch: branch ?? t('changesView.currentBranch') })}
        </button>
        {error !== undefined && <ErrorMessage error={error} />}
      </form>
    </>
  )
}
function WorkingDiff({
  repoId,
  path,
  statusVersion,
  selection,
}: {
  repoId: string
  path: string
  statusVersion: unknown
  selection?: DiffSelectionData
}) {
  const [result, setResult] = useState<{ diff?: FileDiff; error?: unknown; loading: boolean }>({
    loading: true,
  })
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    let active = true
    void Promise.resolve()
      .then(() => {
        if (active) setResult({ loading: true })
        return invoke('git:workingDiff', repoId, path)
      })
      .then(
        (diff) => {
          if (active) setResult({ diff, loading: false })
        },
        (error: unknown) => {
          if (active) setResult({ error, loading: false })
        }
      )
    return () => {
      active = false
    }
  }, [repoId, path, statusVersion, attempt])
  const change = useCallback(
    (value: DiffSelectionData) => useChangesStore.getState().setSelection(repoId, path, value),
    [repoId, path]
  )
  if (result.loading)
    return (
      <p className={styles.message} role="status">
        {t('changesView.loading')}
      </p>
    )
  if (result.error !== undefined)
    return (
      <>
        <ErrorMessage error={result.error} />
        <button onClick={() => setAttempt(attempt + 1)}>{t('changesView.retry')}</button>
      </>
    )
  return result.diff ? (
    <DiffView path={path} diff={result.diff} selection={selection} onSelectionChange={change} />
  ) : null
}
export function ChangesView() {
  const repoId = useAppStore((state) => state.selectedRepositoryId)
  return <RepositoryChanges key={repoId ?? ''} />
}

function RepositoryChanges() {
  const repoId = useAppStore((state) => state.selectedRepositoryId)
  const repo = useRepoStore()
  const status = repo.repoId === repoId ? repo.status : undefined
  const files = status?.files ?? emptyFiles
  const state = useChangesStore((store) => (repoId ? store.repositories[repoId] : undefined))
  const [menu, setMenu] = useState<{ path: string; x: number; y: number }>()
  const [discardPath, setDiscardPath] = useState<string>()
  const [error, setError] = useState<unknown>()
  const closeMenu = useCallback(() => setMenu(undefined), [])
  useEffect(() => {
    if (repoId && status) useChangesStore.getState().sync(repoId, files)
  }, [repoId, files, status])
  if (!repoId) return <p className={styles.message}>{t('changesView.noRepository')}</p>
  if (!status)
    return (
      <div className={styles.message}>
        {repo.error ? (
          <ErrorMessage error={repo.error} />
        ) : (
          <p role="status">{t('changesView.loading')}</p>
        )}
        <button onClick={() => void repo.refresh()}>{t('changesView.retry')}</button>
      </div>
    )
  const selections = state?.selections ?? {}
  const selectedPath = files.some((file) => file.path === state?.path)
    ? state?.path
    : files[0]?.path
  const types = files.map((file) => getSelectionType(selections[file.path] ?? selectAll()))
  const allType =
    types.length && types.every((type) => type === 'all')
      ? 'all'
      : types.every((type) => type === 'none')
        ? 'none'
        : 'partial'
  const setSelection = (path: string, selection: DiffSelectionData) =>
    useChangesStore.getState().setSelection(repoId, path, selection)
  const left = (
    <>
      <div className={styles.listHeader}>
        <Checkbox
          type={allType}
          label={t('changesView.selectAll')}
          disabled={!files.length}
          onChange={() =>
            files.forEach(({ path }) =>
              setSelection(path, allType === 'all' ? selectNone() : selectAll())
            )
          }
        />
        <span>{t('changesView.fileCount', { count: files.length })}</span>
      </div>
      <VirtualList
        items={files}
        rowHeight={28}
        selectedIndex={files.findIndex((file) => file.path === selectedPath)}
        onSelect={(index) => {
          if (files[index]) useChangesStore.getState().selectPath(repoId, files[index].path)
        }}
        getKey={(file) => file.path}
        renderRow={(file) => (
          <div
            className={`${styles.file} ${selectedPath === file.path ? styles.active : ''}`}
            onContextMenu={(event) => {
              event.preventDefault()
              setMenu({ path: file.path, x: event.clientX, y: event.clientY })
            }}
          >
            <Checkbox
              type={getSelectionType(selections[file.path] ?? selectAll())}
              label={t('changesView.include', { path: file.path })}
              onChange={() =>
                setSelection(
                  file.path,
                  getSelectionType(selections[file.path] ?? selectAll()) === 'all'
                    ? selectNone()
                    : selectAll()
                )
              }
            />
            <span className={`${styles.status} ${styles[file.status.kind]}`}>
              {t(`changesView.status.${file.status.kind}`)}
            </span>
            <button
              className={styles.path}
              aria-pressed={selectedPath === file.path}
              title={file.path}
              onClick={() => useChangesStore.getState().selectPath(repoId, file.path)}
            >
              {'oldPath' in file.status && (
                <>
                  <FilePath path={file.status.oldPath} /> →{' '}
                </>
              )}
              <FilePath path={file.path} />
            </button>
          </div>
        )}
      />
      <CommitForm
        key={repoId}
        repoId={repoId}
        branch={status.currentBranch}
        files={files}
        selections={selections}
      />
    </>
  )
  return (
    <div className={styles.root}>
      <SplitPane
        left={left}
        right={
          selectedPath ? (
            <WorkingDiff
              key={`${repoId}:${selectedPath}`}
              repoId={repoId}
              path={selectedPath}
              statusVersion={status}
              selection={selections[selectedPath]}
            />
          ) : (
            <p className={styles.message}>{t('changesView.empty')}</p>
          )
        }
      />
      {error !== undefined && <ErrorMessage error={error} />}
      {menu && (
        <ContextMenu
          x={menu.x}
          y={menu.y}
          onClose={closeMenu}
          items={[
            { label: t('changesView.discard'), onSelect: () => setDiscardPath(menu.path) },
            {
              label: t('changesView.copyPath'),
              onSelect: () => {
                void navigator.clipboard.writeText(menu.path).catch(setError)
              },
            },
          ]}
        />
      )}
      {discardPath && (
        <ConfirmDialog
          message={t('changesView.discardMessage', { path: discardPath })}
          onCancel={() => setDiscardPath(undefined)}
          onConfirm={() => {
            const path = discardPath
            setDiscardPath(undefined)
            void invoke('git:discard', repoId, [path])
              .then(() => useRepoStore.getState().refresh())
              .catch(setError)
          }}
        />
      )}
    </div>
  )
}
