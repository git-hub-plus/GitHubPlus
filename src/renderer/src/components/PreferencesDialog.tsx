import { useEffect, useRef, useState } from 'react'
import type { GitIdentity } from '@shared/ipc/git-advanced'
import { GhpError } from '@shared/errors'
import { invoke } from '../ipc'
import { IdentityDialog } from './dialogs/IdentityDialog'
import type { ThemePreference } from '@shared/models/app'
import type { Language } from '@shared/i18n'
import { useAppStore } from '../state/app-store'
import { useT } from '../i18n'
import { GitHubAccountSection } from './github/GitHubAccountSection'
import { AiSettingsSection } from './ai/AiSettingsSection'
import styles from './PreferencesDialog.module.css'

const themes: ReadonlyArray<ThemePreference> = ['light', 'dark', 'system']
const languages: ReadonlyArray<{ id: Language; label: string }> = [
  { id: 'ko', label: '한국어' },
  { id: 'en', label: 'English' },
]

/** Language and theme apply immediately; there is nothing to save. */
export function PreferencesDialog() {
  const t = useT()
  const open = useAppStore((s) => s.preferencesOpen)
  const setOpen = useAppStore((s) => s.setPreferencesOpen)
  const settings = useAppStore((s) => s.settings)
  const updateSettings = useAppStore((s) => s.updateSettings)
  const repoId = useAppStore((s) => s.selectedRepositoryId)
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const dialog = ref.current
    if (open && dialog && !dialog.open) dialog.showModal()
    if (!open && dialog?.open) dialog.close()
  }, [open])

  return (
    <dialog ref={ref} className={styles.dialog} onClose={() => setOpen(false)}>
      <h1 className={styles.title}>{t('preferences.title')}</h1>
      <label className={styles.field}>
        <span>{t('preferences.language')}</span>
        <select
          value={settings.language}
          onChange={(e) => void updateSettings({ language: e.target.value as Language })}
        >
          {languages.map((l) => (
            <option key={l.id} value={l.id}>
              {l.label}
            </option>
          ))}
        </select>
      </label>
      <fieldset className={styles.field}>
        <legend>{t('preferences.theme')}</legend>
        <div className={styles.choices}>
          {themes.map((theme) => (
            <label key={theme}>
              <input
                type="radio"
                name="theme"
                checked={settings.theme === theme}
                onChange={() => void updateSettings({ theme })}
              />
              {t(`preferences.themes.${theme}`)}
            </label>
          ))}
        </div>
      </fieldset>
      {open && <GitUser key={repoId} repoId={repoId} />}
      {open && <GitHubAccountSection />}
      {open && <AiSettingsSection />}
      <div className={styles.footer}>
        <button onClick={() => setOpen(false)}>{t('common.close')}</button>
      </div>
    </dialog>
  )
}

function GitUser({ repoId }: { repoId?: string }) {
  const t = useT()
  const [identity, setIdentity] = useState<GitIdentity>()
  const [error, setError] = useState<unknown>()
  const [editing, setEditing] = useState(false)
  const [attempt, setAttempt] = useState(0)
  useEffect(() => {
    if (!repoId) return
    let active = true
    void invoke('git:getIdentity', repoId)
      .then((value) => {
        if (active) {
          setIdentity(value)
          setError(undefined)
        }
      })
      .catch((failure) => {
        if (active) setError(failure)
      })
    return () => {
      active = false
    }
  }, [repoId, attempt])
  return (
    <fieldset className={styles.field}>
      <legend>{t('identity.title')}</legend>
      {!repoId ? (
        <p>{t('identity.noRepository')}</p>
      ) : (
        <>
          {identity && (
            <>
              <p>
                {identity.name || t('identity.none')} · {identity.email || t('identity.none')}
              </p>
              <p>{t('identity.source', { source: t(`identity.${identity.source}`) })}</p>
              <button type="button" onClick={() => setEditing(true)}>
                {t('identity.edit')}
              </button>
            </>
          )}
          {!identity && error === undefined && <p role="status">{t('common.loading')}</p>}
          {error !== undefined && (
            <div role="alert">
              {t('identity.failed')}
              <details>
                <summary>{t('common.details')}</summary>
                <pre>
                  {error instanceof GhpError
                    ? `${error.message}\n${error.detail ?? ''}`
                    : String(error)}
                </pre>
              </details>
              <button type="button" onClick={() => setAttempt((value) => value + 1)}>
                {t('common.retry')}
              </button>
            </div>
          )}
          {identity && editing && (
            <IdentityDialog
              repoId={repoId}
              identity={identity}
              onClose={() => setEditing(false)}
              onSaved={(value) => {
                setIdentity(value)
                setEditing(false)
              }}
            />
          )}
        </>
      )}
    </fieldset>
  )
}
