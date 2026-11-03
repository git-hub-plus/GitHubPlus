import { useEffect, useState } from 'react'
import type { CommittedFile, StashEntry } from '@shared/models/git'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import type { FileDiff } from '@shared/models/diff'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { performOperation, useOperationStore } from '../../state/operation-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import { VirtualList } from '../common/VirtualList'
import { DiffView } from '../diff/DiffView'
import styles from './StashMenu.module.css'

export function StashMenu({ repoId }: { repoId: string }) {
  const t = useT()
  const [open, setOpen] = useState(false)
  const [dialog, setDialog] = useState<'create' | 'list'>()
  const [message, setMessage] = useState('')
  const [untracked, setUntracked] = useState(false)
  const busy = useOperationStore((s) => !!s.busy[repoId])
  return (
    <div className={styles.toolbar}>
      <button aria-expanded={open} onClick={() => setOpen(!open)}>
        {t('conflicts.stash.title')}
      </button>
      {open && (
        <div className={styles.menu}>
          <button disabled={busy} onClick={() => setDialog('create')}>
            {t('conflicts.stash.create')}
          </button>
          <button onClick={() => setDialog('list')}>{t('conflicts.stash.list')}</button>
        </div>
      )}
      {dialog === 'create' && (
        <Dialog
          title={t('conflicts.stash.create')}
          busy={busy}
          submitLabel={t('conflicts.stash.create')}
          onClose={() => setDialog(undefined)}
          onSubmit={() => {
            void performOperation(repoId, () =>
              invoke('git:stashCreate', repoId, {
                message: message.trim(),
                includeUntracked: untracked,
              })
            ).then((ok) => {
              if (ok) {
                setDialog(undefined)
                setMessage('')
                setUntracked(false)
              }
            })
          }}
        >
          <label>
            {t('conflicts.stash.message')}
            <input value={message} onChange={(e) => setMessage(e.target.value)} />
          </label>
          <label>
            <input
              type="checkbox"
              checked={untracked}
              onChange={(e) => setUntracked(e.target.checked)}
            />
            {t('conflicts.stash.untracked')}
          </label>
        </Dialog>
      )}
      {dialog === 'list' && <StashPanel repoId={repoId} onClose={() => setDialog(undefined)} />}
    </div>
  )
}
function StashPanel({ repoId, onClose }: { repoId: string; onClose(): void }) {
  const t = useT()
  const [entries, setEntries] = useState<ReadonlyArray<StashEntry>>([])
  const [loaded, setLoaded] = useState(false)
  const [version, setVersion] = useState(0)
  // SHA is the identity: stash names are renumbered after pop/drop.
  const [sha, setSha] = useState<string>()
  const [drop, setDrop] = useState(false)
  const busy = useOperationStore((s) => !!s.busy[repoId])
  const entry = entries.find((e) => e.sha === sha)
  useEffect(() => {
    let active = true
    void invoke('git:stashList', repoId).then(
      (items) => {
        if (active) {
          setEntries(items)
          setSha((old) => (items.some((e) => e.sha === old) ? old : items[0]?.sha))
          setLoaded(true)
        }
      },
      (error) => {
        if (active) {
          showToast(error)
          setEntries([])
          setLoaded(true)
        }
      }
    )
    return () => {
      active = false
    }
  }, [repoId, version])
  const reload = () => {
    setLoaded(false)
    setVersion((v) => v + 1)
  }
  const apply = (pop: boolean) => {
    if (!entry) return
    let outcome: OperationOutcome | undefined
    void performOperation(repoId, async () => {
      outcome = await invoke('git:stashApply', repoId, entry.name, { pop })
      return outcome
    }).then((ok) => {
      if (ok) {
        if (outcome === 'conflicts') onClose()
        else reload()
      }
    })
  }
  return (
    <>
      <Dialog title={t('conflicts.stash.list')} busy={busy} onClose={onClose}>
        <div className={styles.panel}>
          {!loaded ? (
            <p role="status">{t('common.loading')}</p>
          ) : !entries.length ? (
            <p>{t('conflicts.stash.empty')}</p>
          ) : (
            <>
              <div style={{ height: Math.min(entries.length * 28, 140) }}>
                <VirtualList
                  label={t('conflicts.stash.list')}
                  items={entries}
                  rowHeight={28}
                  getKey={(e) => e.sha}
                  selectedIndex={entries.findIndex((e) => e.sha === sha)}
                  onSelect={(i) => setSha(entries[i]?.sha)}
                  renderRow={(e) => (
                    <div className={styles.row}>
                      <button
                        aria-pressed={e.sha === sha}
                        onClick={() => setSha(e.sha)}
                        title={e.message}
                      >
                        {e.name} — {e.message}
                      </button>
                      <span className={styles.meta}>{e.branchName}</span>
                      <time className={styles.meta} dateTime={new Date(e.createdAt).toISOString()}>
                        {new Date(e.createdAt).toLocaleString()}
                      </time>
                    </div>
                  )}
                />
              </div>
              <div className={styles.actions}>
                <button disabled={busy || !entry || !loaded} onClick={() => apply(false)}>
                  {t('conflicts.stash.apply')}
                </button>
                <button disabled={busy || !entry || !loaded} onClick={() => apply(true)}>
                  {t('conflicts.stash.pop')}
                </button>
                <button disabled={busy || !entry || !loaded} onClick={() => setDrop(true)}>
                  {t('conflicts.stash.drop')}
                </button>
              </div>
              {entry && (
                <StashFiles
                  key={`${entry.sha}:${entry.name}:${version}`}
                  repoId={repoId}
                  name={entry.name}
                />
              )}
            </>
          )}
        </div>
      </Dialog>
      {drop && entry && (
        <Dialog
          title={t('conflicts.stash.drop')}
          busy={busy}
          submitLabel={t('conflicts.stash.drop')}
          onClose={() => setDrop(false)}
          onSubmit={() => {
            void performOperation(repoId, () => invoke('git:stashDrop', repoId, entry.name)).then(
              (ok) => {
                if (ok) {
                  setDrop(false)
                  reload()
                }
              }
            )
          }}
        >
          <p>{t('conflicts.stash.dropConfirm', { name: entry.name })}</p>
        </Dialog>
      )}
    </>
  )
}

function StashFiles({ repoId, name }: { repoId: string; name: string }) {
  const t = useT()
  const [files, setFiles] = useState<ReadonlyArray<CommittedFile>>()
  const [path, setPath] = useState<string>()
  useEffect(() => {
    let active = true
    void invoke('git:stashFiles', repoId, name).then(
      (items) => {
        if (active) {
          setFiles(items)
          setPath(items[0]?.path)
        }
      },
      (error) => {
        if (active) {
          showToast(error)
          setFiles([])
        }
      }
    )
    return () => {
      active = false
    }
  }, [repoId, name])
  if (!files) return <p role="status">{t('common.loading')}</p>
  return (
    <>
      <div style={{ height: Math.min(files.length * 28, 112) }}>
        <VirtualList
          label={t('conflicts.stash.files')}
          items={files}
          rowHeight={28}
          getKey={(f) => f.path}
          selectedIndex={files.findIndex((f) => f.path === path)}
          onSelect={(i) => setPath(files[i]?.path)}
          renderRow={(f) => (
            <button type="button" aria-pressed={path === f.path} onClick={() => setPath(f.path)}>
              {f.path}
            </button>
          )}
        />
      </div>
      {path && <StashDiff key={path} repoId={repoId} name={name} path={path} />}
    </>
  )
}
function StashDiff({ repoId, name, path }: { repoId: string; name: string; path: string }) {
  const t = useT()
  const [diff, setDiff] = useState<FileDiff>()
  const [failed, setFailed] = useState(false)
  useEffect(() => {
    let active = true
    void invoke('git:stashDiff', repoId, name, path).then(
      (value) => {
        if (active) setDiff(value)
      },
      (error) => {
        if (active) {
          showToast(error)
          setFailed(true)
        }
      }
    )
    return () => {
      active = false
    }
  }, [repoId, name, path])
  return (
    <div className={styles.preview}>
      {diff ? (
        <DiffView path={path} diff={diff} />
      ) : failed ? (
        <p>{t('changesView.error')}</p>
      ) : (
        <p role="status">{t('common.loading')}</p>
      )}
    </div>
  )
}
