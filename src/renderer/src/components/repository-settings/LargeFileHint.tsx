import { useState } from 'react'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { useRepoStore } from '../../state/repo-store'
import { showToast } from '../../state/toast-store'
import styles from './RepositorySettings.module.css'

export interface LargeFileCandidate {
  readonly path: string
  readonly size: number
  readonly isNew: boolean
}

/** Match the common filename globs offered by this hint; Git remains authoritative. */
function matchesPattern(path: string, pattern: string): boolean {
  if (path === pattern) return true
  const expression = pattern
    .split(/([*?])/)
    .map((part) =>
      part === '*' ? '.*' : part === '?' ? '.' : part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    )
    .join('')
  const candidate = pattern.includes('/') ? path : path.split('/').at(-1)!
  return new RegExp(`^${expression}$`).test(candidate)
}

/** C2 supplies new working-tree files and byte sizes; existing history is unaffected. */
export function LargeFileHint({
  repoId,
  files,
}: {
  repoId: string
  files: ReadonlyArray<LargeFileCandidate>
}) {
  return <LargeFileHintContent key={repoId} repoId={repoId} files={files} />
}

function LargeFileHintContent({
  repoId,
  files,
}: {
  repoId: string
  files: ReadonlyArray<LargeFileCandidate>
}) {
  const t = useT()
  const [pattern, setPattern] = useState<string>()
  const [busy, setBusy] = useState(false)
  const [tracked, setTracked] = useState<ReadonlySet<string>>(new Set())
  const large = files.filter(
    (file) => file.isNew && file.size >= 100 * 1024 * 1024 && !tracked.has(file.path)
  )
  if (large.length === 0) return null
  const selectedPattern = pattern ?? large[0].path
  const track = async () => {
    if (busy || !selectedPattern.trim()) return
    setBusy(true)
    try {
      await invoke('git:lfsTrack', repoId, selectedPattern.trim())
      setTracked(
        (previous) =>
          new Set([
            ...previous,
            ...large
              .filter((file) => matchesPattern(file.path, selectedPattern.trim()))
              .map((file) => file.path),
          ])
      )
      setPattern(undefined)
      await useRepoStore.getState().refresh()
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  return (
    <aside className={styles.hint} aria-label={t('lfs.largeFile.message')}>
      <p>{t('lfs.largeFile.message')}</p>
      <p className={styles.path}>{large.map((file) => file.path).join(', ')}</p>
      <label>
        {t('lfs.settings.pattern')}
        <input
          value={selectedPattern}
          disabled={busy}
          onChange={(event) => setPattern(event.target.value)}
        />
      </label>
      <button type="button" disabled={busy || !selectedPattern.trim()} onClick={() => void track()}>
        {t('lfs.largeFile.track')}
      </button>
    </aside>
  )
}
