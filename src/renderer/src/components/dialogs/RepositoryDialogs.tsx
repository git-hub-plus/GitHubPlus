import { useEffect, useState } from 'react'
import type { AppInfo, RepositoryInfo } from '@shared/models/app'
import { GhpError } from '@shared/errors'
import { invoke } from '../../ipc'
import { useT } from '../../i18n'
import { useAppStore, useSelectedRepository } from '../../state/app-store'
import { useRepoStore } from '../../state/repo-store'
import { useDialogStore } from '../../state/dialog-store'
import { runOperation, useSyncStore, refreshHistory, notifyOperation } from '../../state/sync-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from './Dialog'
import { GitHubClonePicker } from '../github/GitHubClonePicker'
import githubStyles from '../github/GitHub.module.css'

export function normalizeCloneUrl(value: string): string {
  const trimmed = value.trim()
  return /^[\w.-]+\/[\w.-]+$/.test(trimmed)
    ? `https://github.com/${trimmed.replace(/\.git$/, '')}.git`
    : trimmed
}
export function normalizeBranch(value: string): string {
  return value.replace(/\s/g, '-')
}
export function validBranch(value: string): boolean {
  return (
    !!value &&
    value !== '@' &&
    !/^[/.-]|[/.]$|\.\.|@\{|[~^:?*[\\\s]|\/\//.test(value) &&
    !hasControlCharacters(value) &&
    value.split('/').every((part) => !part.startsWith('.') && !part.endsWith('.lock'))
  )
}
function hasControlCharacters(value: string): boolean {
  return [...value].some(
    (character) => character.charCodeAt(0) < 32 || character.charCodeAt(0) === 127
  )
}
async function selectAdded(repo: RepositoryInfo): Promise<void> {
  useAppStore.setState((state) => ({
    repositories: state.repositories.some((r) => r.id === repo.id)
      ? state.repositories
      : [...state.repositories, repo],
  }))
  await useAppStore.getState().selectRepository(repo.id)
  await useRepoStore.getState().refresh()
}
export function RepositoryDialogs() {
  const kind = useDialogStore((s) => s.kind)
  return kind ? <RepositoryDialog key={kind} /> : null
}
function RepositoryDialog() {
  const t = useT()
  const { kind, directory, close, open } = useDialogStore()
  const repository = useSelectedRepository()
  const status = useRepoStore((s) => (s.repoId === repository?.id ? s.status : undefined))
  const defaultDirectory = useAppStore((s) => s.settings.defaultRepositoryDirectory)
  const proposedPath = directory?.replace(/[\\/]+$/, '')
  const splitAt = Math.max(
    proposedPath?.lastIndexOf('/') ?? -1,
    proposedPath?.lastIndexOf('\\') ?? -1
  )
  const createHere = kind === 'create' && proposedPath && splitAt >= 0
  const [path, setPath] = useState(
    createHere ? proposedPath.slice(0, splitAt + 1) : (directory ?? defaultDirectory ?? '')
  )
  const [name, setName] = useState(createHere ? proposedPath.slice(splitAt + 1) : '')
  const [url, setUrl] = useState('')
  const [cloneTab, setCloneTab] = useState<'url' | 'github'>('url')
  const [readme, setReadme] = useState(true)
  const [busy, setBusy] = useState(false)
  const [notRepository, setNotRepository] = useState(false)
  const [info, setInfo] = useState<AppInfo>()
  const active = useSyncStore((s) => s.active)
  useEffect(() => {
    if (kind === 'about') void invoke('app:getInfo').then(setInfo).catch(showToast)
  }, [kind])
  if (!kind) return null
  const title = t(`repoActions.dialogs.${kind}`)
  const chooseDirectory = async () => {
    try {
      const selected = await invoke('dialog:pickDirectory', {
        title: t('repoActions.location'),
        defaultPath: path || undefined,
      })
      if (selected) {
        setPath(selected)
        setNotRepository(false)
      }
    } catch (error) {
      showToast(error)
    }
  }
  const submit = async () => {
    if (busy) return
    setBusy(true)
    try {
      if (kind === 'add') await selectAdded(await invoke('repos:add', path.trim()))
      else if (kind === 'create')
        await selectAdded(
          await invoke('repos:create', {
            parentDirectory: path.trim(),
            name: name.trim(),
            addReadme: readme,
          })
        )
      else if (kind === 'clone')
        await selectAdded(
          await runOperation('clone', (opId) =>
            invoke('git:clone', { url: normalizeCloneUrl(url), path: path.trim(), opId })
          )
        )
      else if (kind === 'branch' && repository) {
        await invoke('git:createBranch', repository.id, {
          name,
          startPoint: status?.currentBranch ?? status?.headSha,
          checkout: true,
        })
        await useRepoStore.getState().refresh()
        await refreshHistory(repository.id)
      }
      close()
      if (kind === 'branch') notifyOperation('repoActions.completed.branch', { branch: name })
      else showToast()
    } catch (error) {
      if (kind === 'add' && error instanceof GhpError && error.kind === 'not-a-repository')
        setNotRepository(true)
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  const invalidName =
    kind === 'branch'
      ? !validBranch(name)
      : !name.trim() ||
        /[<>:"/\\|?*]/.test(name) ||
        hasControlCharacters(name) ||
        name === '.' ||
        name === '..'
  const disabled =
    kind === 'branch'
      ? !repository || invalidName || !!active
      : !path.trim() ||
        (kind === 'create' && invalidName) ||
        (kind === 'clone' && (!url.trim() || !!active))
  return (
    <Dialog
      title={title}
      onClose={close}
      onSubmit={kind === 'about' ? undefined : () => void submit()}
      busy={busy}
      disabled={disabled}
      submitLabel={kind === 'about' ? undefined : t(`repoActions.submit.${kind}`)}
    >
      {kind === 'about' ? (
        <>
          <p>{info ? `${info.name} ${info.version}` : t('common.loading')}</p>
          <p>
            {t('repoActions.gitVersion', {
              version: info?.gitVersion ?? t('repoActions.unavailable'),
            })}
          </p>
          <p>{t('repoActions.license')}</p>
        </>
      ) : (
        <>
          {(kind === 'create' || kind === 'branch') && (
            <label>
              {t('repoActions.name')}
              <input
                value={name}
                onChange={(event) =>
                  setName(
                    kind === 'branch' ? normalizeBranch(event.target.value) : event.target.value
                  )
                }
              />
            </label>
          )}
          {kind === 'branch' && (
            <>
              <p>
                {t('repoActions.startPoint', {
                  branch:
                    status?.currentBranch ?? status?.headSha?.slice(0, 7) ?? t('toolbar.noBranch'),
                })}
              </p>
              {name && invalidName && <p role="alert">{t('repoActions.invalidBranch')}</p>}
            </>
          )}
          {kind === 'clone' && (
            <>
              <div
                role="tablist"
                aria-label={t('github.cloneSource')}
                className={githubStyles.tabs}
              >
                {(['url', 'github'] as const).map((tab) => (
                  <button
                    key={tab}
                    type="button"
                    role="tab"
                    aria-selected={cloneTab === tab}
                    onClick={() => setCloneTab(tab)}
                    onKeyDown={(event) => {
                      if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
                        event.preventDefault()
                        setCloneTab(tab === 'url' ? 'github' : 'url')
                        ;(
                          event.currentTarget.parentElement?.querySelector(
                            `[aria-selected="false"]`
                          ) as HTMLButtonElement | null
                        )?.focus()
                      }
                    }}
                  >
                    {t(tab === 'url' ? 'github.urlTab' : 'github.title')}
                  </button>
                ))}
              </div>
              {cloneTab === 'github' && <GitHubClonePicker url={url} onSelect={setUrl} />}
              <label>
                {t('repoActions.url')}
                <input
                  value={url}
                  onChange={(event) => setUrl(event.target.value)}
                  placeholder={t('repoActions.urlPlaceholder')}
                />
              </label>
            </>
          )}
          {kind !== 'branch' && (
            <>
              <label>
                {t(kind === 'clone' ? 'repoActions.cloneLocation' : 'repoActions.location')}
                <input
                  value={path}
                  onChange={(event) => {
                    setPath(event.target.value)
                    setNotRepository(false)
                  }}
                />
              </label>
              <button type="button" disabled={busy} onClick={() => void chooseDirectory()}>
                {t('repoActions.chooseFolder')}
              </button>
            </>
          )}
          {kind === 'create' && (
            <label>
              <span>
                <input
                  type="checkbox"
                  checked={readme}
                  onChange={(event) => setReadme(event.target.checked)}
                />{' '}
                {t('repoActions.readme')}
              </span>
            </label>
          )}
          {notRepository && (
            <div>
              <p>{t('repoActions.errors.notRepository')}</p>
              <button type="button" onClick={() => open('create', path)}>
                {t('repoActions.createHere')}
              </button>
            </div>
          )}
          {kind === 'clone' && busy && (
            <progress
              aria-label={t('repoActions.progress')}
              max={1}
              value={active?.progress?.value}
            />
          )}
        </>
      )}
    </Dialog>
  )
}
