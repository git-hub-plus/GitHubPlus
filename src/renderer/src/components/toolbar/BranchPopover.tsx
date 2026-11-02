import { useEffect, useRef, useState } from 'react'
import type { Branch } from '@shared/models/git'
import { invoke } from '../../ipc'
import { useT } from '../../i18n'
import { useDialogStore } from '../../state/dialog-store'
import { useRepoStore } from '../../state/repo-store'
import { runOperation, useSyncStore } from '../../state/sync-store'
import { showToast } from '../../state/toast-store'
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
    void invoke('git:branches', repoId)
      .then((items) => {
        if (!cancelled) {
          setBranches(items)
          setLoaded(true)
        }
      })
      .catch(showToast)
    return () => {
      cancelled = true
    }
  }, [repoId])
  const checkout = async (branch: Branch) => {
    setBusy(true)
    try {
      await runOperation(repoId, (opId) => invoke('git:checkout', repoId, branch.name, { opId }))
      await useRepoStore.getState().refresh()
      onClose()
      showToast()
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
      setEdit(undefined)
      setBranches(await invoke('git:branches', repoId))
      showToast()
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  // Temporary fixed-row window; U1 owns the shared VirtualList implementation.
  const [scrollTop, setScrollTop] = useState(0)
  const list = useRef<HTMLDivElement>(null)
  const visible = branches.filter((branch) =>
    branch.name.toLowerCase().includes(query.toLowerCase())
  )
  const rows = (['local', 'remote'] as const).flatMap((type) => [
    { key: type, type, branch: undefined as Branch | undefined },
    ...visible
      .filter((b) => b.type === type)
      .map((branch) => ({ key: `${type}/${branch.name}`, type, branch })),
  ])
  const start = Math.max(0, Math.floor(scrollTop / 28) - 3)
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
            setScrollTop(0)
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
        <div
          ref={list}
          style={{ height: Math.min(rows.length * 28, 280), overflowY: 'auto' }}
          onScroll={(event) => setScrollTop(event.currentTarget.scrollTop)}
          onKeyDown={(event) => {
            if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return
            const row = (event.target as HTMLElement).closest<HTMLElement>('[data-branch-index]')
            if (!row) return
            event.preventDefault()
            event.stopPropagation()
            const direction = event.key === 'ArrowDown' ? 1 : -1
            let next = Number(row.dataset.branchIndex) + direction
            while (next >= 0 && next < rows.length && !rows[next].branch) next += direction
            if (next < 0 || next >= rows.length) return
            if (next * 28 < scrollTop || next * 28 + 28 > scrollTop + 280) {
              list.current!.scrollTop = next * 28
              setScrollTop(next * 28)
            }
            const focus = () =>
              list.current
                ?.querySelector<HTMLElement>(`[data-branch-index="${next}"] button:not(:disabled)`)
                ?.focus()
            if (list.current?.querySelector(`[data-branch-index="${next}"]`)) focus()
            else requestAnimationFrame(focus)
          }}
        >
          <div style={{ height: rows.length * 28, position: 'relative' }}>
            {rows.slice(start, start + 17).map(({ key, type, branch }, index) => (
              <div
                key={key}
                data-branch-index={start + index}
                style={{
                  position: 'absolute',
                  top: (start + index) * 28,
                  height: 28,
                  width: '100%',
                }}
                className={styles.row}
              >
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
            ))}
          </div>
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
