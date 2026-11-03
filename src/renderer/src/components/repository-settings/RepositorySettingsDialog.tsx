import { useEffect, useState } from 'react'
import { create } from 'zustand'
import type { RepositoryInfo } from '@shared/models/app'
import type { GitProgress, Remote } from '@shared/models/git'
import type { LfsStatus, Submodule } from '@shared/ipc/git-advanced'
import { invoke, subscribe } from '../../ipc'
import { useT } from '../../i18n'
import { useRepoStore } from '../../state/repo-store'
import { Dialog } from '../dialogs/Dialog'
import { GhpError } from '@shared/errors'
import styles from './RepositorySettings.module.css'

const useSettingsStore = create<{ repository?: RepositoryInfo }>(() => ({}))

export function openRepositorySettings(repository: RepositoryInfo): void {
  useSettingsStore.setState({ repository })
}

export function RepositorySettingsHost() {
  const repository = useSettingsStore((state) => state.repository)
  return repository ? (
    <RepositorySettingsDialog
      key={repository.id}
      repository={repository}
      onClose={() => useSettingsStore.setState({ repository: undefined })}
    />
  ) : null
}

export function RepositorySettingsDialog({
  repository,
  onClose,
}: {
  repository: RepositoryInfo
  onClose(): void
}) {
  const t = useT()
  const [tab, setTab] = useState<'remotes' | 'lfs' | 'submodules'>('remotes')
  const [remotes, setRemotes] = useState<ReadonlyArray<Remote>>()
  const [lfs, setLfs] = useState<LfsStatus>()
  const [submodules, setSubmodules] = useState<ReadonlyArray<Submodule>>()
  const [pattern, setPattern] = useState('')
  const [busy, setBusy] = useState(false)
  const [progress, setProgress] = useState<GitProgress>()
  const [failed, setFailed] = useState(false)
  const [revision, setRevision] = useState(0)
  const [error, setError] = useState<unknown>()

  useEffect(() => {
    let active = true
    const load = async () => {
      const results = await Promise.allSettled([
        invoke('git:remotes', repository.id),
        invoke('git:lfsStatus', repository.id),
        invoke('git:submodules', repository.id),
      ])
      if (!active) return
      setFailed(results.some((result) => result.status === 'rejected'))
      const rejection = results.find((result) => result.status === 'rejected')
      setError(rejection?.status === 'rejected' ? rejection.reason : undefined)
      const [remoteResult, lfsResult, submoduleResult] = results
      if (remoteResult.status === 'fulfilled') setRemotes(remoteResult.value)
      if (lfsResult.status === 'fulfilled') setLfs(lfsResult.value)
      if (submoduleResult.status === 'fulfilled') setSubmodules(submoduleResult.value)
    }
    void load()
    return () => {
      active = false
    }
  }, [repository.id, revision])

  const changePattern = async (value: string, remove = false) => {
    if (busy || !(remove ? value : value.trim())) return
    setBusy(true)
    setError(undefined)
    try {
      await invoke(
        remove ? 'git:lfsUntrack' : 'git:lfsTrack',
        repository.id,
        remove ? value : value.trim()
      )
      setLfs(await invoke('git:lfsStatus', repository.id))
      if (!remove) setPattern('')
      await useRepoStore.getState().refresh()
    } catch (error) {
      setError(error)
    } finally {
      setBusy(false)
    }
  }

  const updateSubmodules = async () => {
    if (busy) return
    setBusy(true)
    setError(undefined)
    setProgress(undefined)
    const opId = crypto.randomUUID()
    const off = subscribe('git:progress', (event) => {
      if (event.opId === opId) setProgress(event.progress)
    })
    try {
      await invoke('git:updateSubmodules', repository.id, { opId })
      setSubmodules(await invoke('git:submodules', repository.id))
      await useRepoStore.getState().refresh()
    } catch (error) {
      setError(error)
    } finally {
      off()
      setBusy(false)
      setProgress(undefined)
    }
  }

  return (
    <Dialog
      title={`${t('lfs.settings.title')} ${repository.alias ?? repository.name}`}
      onClose={onClose}
      busy={busy}
    >
      <div className={styles.tabs} role="tablist" aria-label={t('lfs.settings.title')}>
        {(['remotes', 'lfs', 'submodules'] as const).map((value, index, tabs) => (
          <button
            key={value}
            type="button"
            role="tab"
            id={`repository-settings-${value}`}
            aria-selected={tab === value}
            aria-controls="repository-settings-panel"
            tabIndex={tab === value ? 0 : -1}
            onClick={() => setTab(value)}
            onKeyDown={(event) => {
              let next: typeof value | undefined
              if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length]
              if (event.key === 'ArrowLeft') next = tabs[(index + tabs.length - 1) % tabs.length]
              if (event.key === 'Home') next = tabs[0]
              if (event.key === 'End') next = tabs[tabs.length - 1]
              if (next) {
                event.preventDefault()
                setTab(next)
                document.getElementById(`repository-settings-${next}`)?.focus()
              }
            }}
          >
            {t(`lfs.settings.${value}`)}
          </button>
        ))}
      </div>
      {error !== undefined && <SettingsError error={error} />}
      <section
        id="repository-settings-panel"
        role="tabpanel"
        aria-labelledby={`repository-settings-${tab}`}
        className={styles.panel}
      >
        {failed && (
          <button
            type="button"
            onClick={() => {
              setFailed(false)
              setRevision((value) => value + 1)
            }}
          >
            {t('common.retry')}
          </button>
        )}
        {tab === 'remotes' &&
          (remotes === undefined ? (
            <p>{t('common.loading')}</p>
          ) : remotes.length === 0 ? (
            <p>{t('lfs.settings.noRemotes')}</p>
          ) : (
            <ul className={styles.list}>
              {remotes.map((remote) => (
                <li key={remote.name}>
                  <strong>{remote.name}</strong>
                  <span className={styles.path}>{remote.url}</span>
                </li>
              ))}
            </ul>
          ))}
        {tab === 'lfs' &&
          (!lfs ? (
            <p>{t('common.loading')}</p>
          ) : (
            <>
              <p role="status">
                {t(lfs.available ? 'lfs.settings.available' : 'lfs.settings.unavailable')} ·{' '}
                {t(
                  lfs.installedInRepository ? 'lfs.settings.installed' : 'lfs.settings.notInstalled'
                )}
              </p>
              <h3>{t('lfs.settings.patterns')}</h3>
              {lfs.trackedPatterns.length === 0 ? (
                <p>{t('lfs.settings.noPatterns')}</p>
              ) : (
                <ul className={styles.list}>
                  {lfs.trackedPatterns.map((item) => (
                    <li key={item}>
                      <code>{item}</code>
                      <button
                        type="button"
                        disabled={busy || !lfs.available}
                        aria-label={`${t('lfs.settings.remove')} ${item}`}
                        onClick={() => void changePattern(item, true)}
                      >
                        {t('lfs.settings.remove')}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
              <label>
                {t('lfs.settings.pattern')}
                <input
                  value={pattern}
                  placeholder={t('lfs.settings.patternPlaceholder')}
                  disabled={busy || !lfs.available}
                  onChange={(event) => setPattern(event.target.value)}
                  onKeyDown={(event) => {
                    if (event.key === 'Enter') {
                      event.preventDefault()
                      void changePattern(pattern)
                    }
                  }}
                />
              </label>
              <button
                type="button"
                disabled={busy || !lfs.available || !pattern.trim()}
                onClick={() => void changePattern(pattern)}
              >
                {t('lfs.settings.add')}
              </button>
            </>
          ))}
        {tab === 'submodules' &&
          (submodules === undefined ? (
            <p>{t('common.loading')}</p>
          ) : (
            <>
              {submodules.length === 0 ? (
                <p>{t('lfs.settings.noSubmodules')}</p>
              ) : (
                <ul className={styles.list}>
                  {submodules.map((item) => (
                    <li key={item.path}>
                      <div className={styles.submodule}>
                        <strong>{item.path}</strong>
                        <span>{t(`lfs.settings.statuses.${item.status}`)}</span>
                        {item.url && <span className={styles.path}>{item.url}</span>}
                      </div>
                    </li>
                  ))}
                </ul>
              )}
              <button
                type="button"
                disabled={busy || submodules.length === 0}
                onClick={() => void updateSubmodules()}
              >
                {t('lfs.settings.updateAll')}
              </button>
              {busy && (
                <div role="status">
                  <p>{t('lfs.settings.updating')}</p>
                  <progress
                    aria-label={t('lfs.settings.updating')}
                    max={1}
                    value={progress?.value}
                  />
                  {progress?.description && <p>{progress.description}</p>}
                </div>
              )}
            </>
          ))}
      </section>
    </Dialog>
  )
}

function SettingsError({ error }: { error: unknown }) {
  const t = useT()
  const kind = error instanceof GhpError ? error.kind : 'unknown'
  const key =
    kind === 'not-a-repository'
      ? 'repoActions.errors.notRepository'
      : kind === 'invalid-argument'
        ? 'repoActions.errors.invalid'
        : kind === 'network'
          ? 'repoActions.errors.network'
          : kind === 'authentication-failed'
            ? 'repoActions.errors.authentication'
            : kind === 'not-found'
              ? 'repoActions.errors.notFound'
              : 'repoActions.errors.unknown'
  const detail =
    error instanceof Error
      ? [error.message, error instanceof GhpError ? error.detail : undefined]
          .filter(Boolean)
          .join('\n')
      : String(error)
  return (
    <div role="alert">
      <p>{t(key)}</p>
      <details>
        <summary>{t('common.details')}</summary>
        <pre>{detail}</pre>
      </details>
    </div>
  )
}
