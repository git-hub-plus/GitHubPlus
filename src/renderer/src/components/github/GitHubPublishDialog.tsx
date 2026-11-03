import { useEffect, useState } from 'react'
import type { RepositoryInfo } from '@shared/models/app'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { useGitHubStore } from '../../state/github-store'
import { runOperation, useSyncStore } from '../../state/sync-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import { GitHubSignIn } from './GitHubAccountSection'
import { GitHubFailure } from './GitHubFailure'

export function GitHubPublishDialog({
  repository,
  onClose,
}: {
  repository: RepositoryInfo
  onClose(): void
}) {
  const t = useT()
  const [name, setName] = useState(
    repository.path
      .replace(/[\\/]+$/, '')
      .split(/[\\/]/)
      .pop() ?? repository.name
  )
  const [description, setDescription] = useState('')
  const [isPrivate, setPrivate] = useState(true)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>()
  const account = useGitHubStore((state) => state.account)
  const active = useSyncStore((state) => state.active)
  useEffect(() => {
    void useGitHubStore.getState().refreshAccount().catch(setError)
  }, [])
  const publish = async () => {
    if (busy) return
    setBusy(true)
    setError(undefined)
    try {
      await runOperation(repository.id, (opId) =>
        invoke('github:publish', repository.id, {
          name: name.trim(),
          description: description.trim() || undefined,
          private: isPrivate,
          opId,
        })
      )
      showToast('github.published')
      onClose()
    } catch (error) {
      setError(error)
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  return (
    <Dialog
      title={t('github.publishTitle')}
      onClose={onClose}
      busy={busy}
      onSubmit={() => void publish()}
      submitLabel={t('github.publish')}
      disabled={!account || !/^[\w.-]+$/.test(name.trim()) || !!active}
    >
      {!account && <GitHubSignIn />}
      <label>
        {t('github.name')}
        <input value={name} onChange={(event) => setName(event.target.value)} />
      </label>
      <label>
        {t('github.description')}
        <input value={description} onChange={(event) => setDescription(event.target.value)} />
      </label>
      <label>
        <span>
          <input
            type="checkbox"
            checked={isPrivate}
            onChange={(event) => setPrivate(event.target.checked)}
          />{' '}
          {t('github.private')}
        </span>
      </label>
      {busy && (
        <progress aria-label={t('github.progress')} max={1} value={active?.progress?.value} />
      )}
      <GitHubFailure error={error} />
    </Dialog>
  )
}
