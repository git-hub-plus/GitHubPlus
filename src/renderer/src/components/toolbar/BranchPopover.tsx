import { useEffect, useState } from 'react'
import type { Branch } from '@shared/models/git'
import { invoke, subscribe } from '../../ipc'
import { useT } from '../../i18n'
import { useDialogStore } from '../../state/dialog-store'
import { useRepoStore } from '../../state/repo-store'
import { runOperation, useSyncStore, refreshHistory, notifyOperation } from '../../state/sync-store'
import { showToast } from '../../state/toast-store'
import { VirtualList } from '../common/VirtualList'
import { Popover } from '../common/Popover'
import { Dialog } from '../dialogs/Dialog'
import { normalizeBranch, validBranch } from '../dialogs/RepositoryDialogs'
import styles from './Actions.module.css'

export function BranchPopover({ repoId, onClose }: { repoId: string; onClose(): void }) {
  const t = useT()
  const [branches, setBranches] = useState<ReadonlyArray<Branch>>([])
  const [query, setQuery] = useState('')
  const [loaded, setLoaded] = useState(false)
  const [edit, setEdit] = useState<{ branch: Branch; action: 'rename' | 'delete' }>()
  const [name, setName] = useState('')
  const [busy, setBusy] = useState(false)
  const active = useSyncStore((s) => s.active)
  useEffect(() => {
    let cancelled = false
    let version = 0
    const load = async () => {
      const request = ++version
      try {
        const items = await invoke('git:branches', repoId)
        if (!cancelled && request === version) {
          setBranches(items)
          setLoaded(true)
        }
      } catch (error) {
        if (!cancelled) showToast(error)
      }
    }
    void load()
    const stop = subscribe('git:repoChanged', (event) => {
      if (event.repoId === repoId) void load()
    })
    const stopSync = useSyncStore.subscribe((state, previous) => {
      if (previous.active?.repoId === repoId && !state.active) void load()
    })
    return () => {
      cancelled = true
      stop()
      stopSync()
    }
  }, [repoId])
  const checkout = async (branch: Branch) => {
    setBusy(true)
    try {
      await runOperation(repoId, (opId) => invoke('git:checkout', repoId, branch.name, { opId }))
      await useRepoStore.getState().refresh()
      onClose()
      notifyOperation('repoActions.completed.checkout', { branch: branch.name })
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  const changeBranch = async () => {
    if (!edit || busy) return
    setBusy(true)
    try {
      if (edit.action === 'rename') await invoke('git:renameBranch', repoId, edit.branch.name, name)
      else
        await invoke('git:deleteBranch', repoId, edit.branch.name, {
          deleteRemote: edit.branch.type === 'remote',
        })
      await useRepoStore.getState().refresh()
      await refreshHistory(repoId)
      setEdit(undefined)
      setBranches(await invoke('git:branches', repoId))
      notifyOperation(`repoActions.completed.${edit.action}`, {
        branch: edit.action === 'rename' ? name : edit.branch.name,
      })
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  const [selectedIndex, setSelectedIndex] = useState(-1)
  const visible = branches.filter((branch) =>
    branch.name.toLowerCase().includes(query.toLowerCase())
  )
  const rows = (['local', 'remote'] as const).flatMap((type) => [
    { key: type, type, branch: undefined as Branch | undefined },
    ...visible
      .filter((b) => b.type === type)
      .map((branch) => ({ key: `${type}/${branch.name}`, type, branch })),
  ])
  return (
    <>
      <Popover label={t('toolbar.branch')} onClose={onClose}>
        <input
          type="search"
          aria-label={t('repoActions.searchBranches')}
          placeholder={t('repoActions.searchBranches')}
          value={query}
          onChange={(event) => {
            setQuery(event.target.value)
            setSelectedIndex(-1)
          }}
        />
        <button
          disabled={!!active || busy}
          onClick={() => {
            useDialogStore.getState().open('branch')
            onClose()
          }}
        >
          {t('repoActions.dialogs.branch')}
        </button>
        {!loaded && <p>{t('common.loading')}</p>}
        {loaded && !visible.length && <p>{t('repoActions.noBranches')}</p>}
        <div style={{ height: Math.min(rows.length * 28, 280) }}>
          <VirtualList
            items={rows}
            rowHeight={28}
            getKey={(row) => row.key}
            selectedIndex={selectedIndex}
            onSelect={setSelectedIndex}
            onActivate={(index) => {
              const branch = rows[index]?.branch
              if (branch && !branch.isCurrent && !active && !busy) void checkout(branch)
            }}
            renderRow={({ type, branch }) => (
              <div className={styles.row}>
                {branch ? (
                  <>
                    <button
                      disabled={!!active || busy || branch.isCurrent}
                      aria-current={branch.isCurrent || undefined}
                      onClick={() => void checkout(branch)}
                    >
                      {branch.name}
                    </button>
                    {branch.type === 'local' && (
                      <button
                        disabled={busy || !!active}
                        aria-label={t('repoActions.renameBranch', { branch: branch.name })}
                        onClick={() => {
                          setEdit({ branch, action: 'rename' })
                          setName(branch.name)
                        }}
                      >
                        {t('repoActions.rename')}
                      </button>
                    )}
                    <button
                      disabled={branch.isCurrent || busy || !!active}
                      aria-label={t('repoActions.deleteBranch', { branch: branch.name })}
                      onClick={() => setEdit({ branch, action: 'delete' })}
                    >
                      {t('repoActions.delete')}
                    </button>
                  </>
                ) : (
                  <h3>{t(`repoActions.${type}`)}</h3>
                )}
              </div>
            )}
          />
        </div>
      </Popover>
      {edit && (
        <Dialog
          title={t(edit.action === 'rename' ? 'repoActions.rename' : 'repoActions.delete')}
          onClose={() => setEdit(undefined)}
          onSubmit={() => void changeBranch()}
          busy={busy}
          disabled={edit.action === 'rename' && !validBranch(name)}
        >
          {edit.action === 'rename' ? (
            <label>
              {t('repoActions.name')}
              <input
                value={name}
                onChange={(event) => setName(normalizeBranch(event.target.value))}
              />
              {!validBranch(name) && <p>{t('repoActions.invalidBranch')}</p>}
            </label>
          ) : (
            <p>{t('repoActions.confirmDelete', { branch: edit.branch.name })}</p>
          )}
        </Dialog>
      )}
    </>
  )
}
