import { useEffect, useRef, useState } from 'react'
import { GhpError } from '@shared/errors'
import { selectAll } from '@shared/models/diff-selection'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { useAppStore, useSelectedRepository } from '../../state/app-store'
import { useChangesStore } from '../../state/changes-store'
import { useRepoStore } from '../../state/repo-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import styles from './DropZone.module.css'

export function DropZone() {
  const t = useT()
  const repo = useSelectedRepository()
  const [active, setActive] = useState(false)
  const [sources, setSources] = useState<string[]>()
  const [destination, setDestination] = useState('')
  const [commitNow, setCommitNow] = useState(false)
  const [summary, setSummary] = useState('')
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<{ copied: number; skipped: number }>()
  const depth = useRef(0)
  const pending = useRef(false)
  const [dropRepo, setDropRepo] = useState<typeof repo>()

  useEffect(() => {
    if (!repo) return
    const isFiles = (event: DragEvent) =>
      Array.from(event.dataTransfer?.types ?? []).includes('Files')
    const enter = (event: DragEvent) => {
      if (!isFiles(event)) return
      event.preventDefault()
      if (busy || sources) return
      depth.current++
      setActive(true)
    }
    const over = (event: DragEvent) => {
      if (!isFiles(event)) return
      event.preventDefault()
      if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy'
    }
    const leave = (event: DragEvent) => {
      if (!isFiles(event)) return
      depth.current = Math.max(0, depth.current - 1)
      if (!depth.current) setActive(false)
    }
    const reset = () => {
      depth.current = 0
      setActive(false)
    }
    const drop = (event: DragEvent) => {
      if (!isFiles(event)) return
      event.preventDefault()
      reset()
      if (busy || sources) return
      try {
        const paths = Array.from(event.dataTransfer?.files ?? []).map((file) =>
          window.ghp.getPathForFile(file)
        )
        if (!paths.length || paths.some((path) => !path)) {
          showToast(new GhpError({ kind: 'invalid-argument', message: t('ai.drop.invalidPaths') }))
          return
        }
        const path = useChangesStore.getState().repositories[repo.id]?.path ?? ''
        setDestination(path.includes('/') ? path.slice(0, path.lastIndexOf('/')) : '')
        setDropRepo(repo)
        setCommitNow(false)
        setSummary('')
        setSources([...new Set(paths)])
        setResult(undefined)
      } catch (error) {
        showToast(error)
      }
    }
    window.addEventListener('dragenter', enter)
    window.addEventListener('dragover', over)
    window.addEventListener('dragleave', leave)
    window.addEventListener('drop', drop)
    window.addEventListener('dragend', reset)
    window.addEventListener('blur', reset)
    return () => {
      window.removeEventListener('dragenter', enter)
      window.removeEventListener('dragover', over)
      window.removeEventListener('dragleave', leave)
      window.removeEventListener('drop', drop)
      window.removeEventListener('dragend', reset)
      window.removeEventListener('blur', reset)
      depth.current = 0
    }
  }, [repo, busy, sources, t])

  const copy = async () => {
    if (!dropRepo || !sources || pending.current) return
    pending.current = true
    setBusy(true)
    try {
      const copied = await invoke('files:copyIntoRepository', dropRepo.id, {
        sources,
        targetDirectory: destination,
      })
      setSources(undefined)
      setActive(false)
      setResult({ copied: copied.copied.length, skipped: copied.skipped.length })
      showToast('ai.drop.done')
      if (useAppStore.getState().selectedRepositoryId === dropRepo.id) {
        useAppStore.getState().setTab('changes')
        await useRepoStore.getState().refresh()
        const files = useRepoStore.getState().status?.files ?? []
        const changes = useChangesStore.getState()
        changes.sync(dropRepo.id, files)
        for (const path of copied.copied) changes.setSelection(dropRepo.id, path, selectAll())
        if (copied.copied[0]) changes.selectPath(dropRepo.id, copied.copied[0])
      }
      if (commitNow && copied.copied.length) {
        try {
          await invoke('git:commit', dropRepo.id, {
            summary: summary.trim(),
            description: '',
            files: copied.copied.map((path) => ({ path, selection: selectAll() })),
          })
        } catch (error) {
          useChangesStore.getState().setMessageDraft(dropRepo.id, {
            summary: summary.trim(),
            description: '',
          })
          throw error
        }
        await useRepoStore.getState().refresh()
        showToast('ai.drop.committed')
      }
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
      pending.current = false
    }
  }

  return (
    <>
      {active && repo && !sources && (
        <div className={styles.overlay} role="status">
          {t('ai.drop.overlay')}
        </div>
      )}
      {result && (
        <aside className={styles.result} role="status">
          <span>{t('ai.drop.result', result)}</span>
          <button onClick={() => setResult(undefined)}>{t('common.close')}</button>
        </aside>
      )}
      {sources && dropRepo && (
        <Dialog
          title={t('ai.drop.title')}
          onClose={() => setSources(undefined)}
          onSubmit={() => void copy()}
          submitLabel={t('ai.drop.copy')}
          busy={busy}
          disabled={commitNow && !summary.trim()}
        >
          <p>{dropRepo.path}</p>
          <label>
            {t('ai.drop.target')}
            <input
              value={destination}
              disabled={busy}
              onChange={(event) => setDestination(event.target.value)}
            />
          </label>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              void invoke('dialog:pickDirectory', { defaultPath: dropRepo.path })
                .then((path) => {
                  if (path) setDestination(path)
                })
                .catch(showToast)
            }}
          >
            {t('ai.drop.chooseFolder')}
          </button>
          <label className={styles.check}>
            <input
              type="checkbox"
              checked={commitNow}
              disabled={busy}
              onChange={(event) => setCommitNow(event.target.checked)}
            />
            {t('ai.drop.commitNow')}
          </label>
          {commitNow && (
            <label>
              {t('ai.drop.summary')}
              <input
                value={summary}
                disabled={busy}
                onChange={(event) => setSummary(event.target.value)}
              />
            </label>
          )}
        </Dialog>
      )}
    </>
  )
}
