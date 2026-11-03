import { useState } from 'react'
import type { GitIdentity } from '@shared/ipc/git-advanced'
import { GhpError } from '@shared/errors'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { Dialog } from './Dialog'

export function IdentityDialog({
  repoId,
  identity,
  onClose,
  onSaved,
}: {
  repoId: string
  identity: GitIdentity
  onClose(): void
  onSaved(identity: GitIdentity): void
}) {
  const t = useT()
  const [name, setName] = useState(identity.name ?? '')
  const [email, setEmail] = useState(identity.email ?? '')
  const [scope, setScope] = useState<'repository' | 'global'>(
    identity.source === 'global' ? 'global' : 'repository'
  )
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>()
  const valid = !!name.trim() && /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(email.trim())
  const save = async () => {
    if (busy || !valid) return
    setBusy(true)
    setError(undefined)
    try {
      const result = await invoke('git:setIdentity', repoId, {
        name: name.trim(),
        email: email.trim(),
        scope,
      })
      onSaved(result)
    } catch (failure) {
      setError(failure)
    } finally {
      setBusy(false)
    }
  }
  return (
    <Dialog
      title={t('identity.title')}
      onClose={onClose}
      onSubmit={() => void save()}
      submitLabel={t('common.save')}
      busy={busy}
      disabled={!valid}
    >
      <p>{t('identity.disclosure')}</p>
      <label>
        {t('identity.name')}
        <input required value={name} disabled={busy} onChange={(e) => setName(e.target.value)} />
      </label>
      <label>
        {t('identity.email')}
        <input
          required
          type="email"
          value={email}
          disabled={busy}
          onChange={(e) => setEmail(e.target.value)}
        />
      </label>
      <fieldset disabled={busy}>
        <legend>{t('identity.scope')}</legend>
        {(['repository', 'global'] as const).map((value) => (
          <label key={value}>
            <span>
              <input
                type="radio"
                name="identity-scope"
                checked={scope === value}
                onChange={() => setScope(value)}
              />{' '}
              {t(`identity.${value}`)}
            </span>
          </label>
        ))}
      </fieldset>
      <p>{t('identity.mixedScope')}</p>
      {!!email && !valid && <p role="status">{t('identity.invalid')}</p>}
      {error !== undefined && (
        <div role="alert">
          {t(
            error instanceof GhpError && error.kind === 'invalid-argument'
              ? 'identity.invalid'
              : 'identity.failed'
          )}
          <details>
            <summary>{t('common.details')}</summary>
            <pre>
              {error instanceof GhpError
                ? `${error.message}\n${error.detail ?? ''}`
                : String(error)}
            </pre>
          </details>
        </div>
      )}
    </Dialog>
  )
}
