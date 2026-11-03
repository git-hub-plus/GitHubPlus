import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { DeviceFlowStart } from '@shared/ipc/integrations'
import { invoke } from '../../ipc'
import { useT } from '../../i18n'
import { useGitHubStore } from '../../state/github-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import { GitHubFailure } from './GitHubFailure'
import styles from './GitHub.module.css'

export function GitHubSignIn() {
  const t = useT()
  const [flow, setFlow] = useState<DeviceFlowStart>()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>()
  const generation = useRef(0)
  const cancel = async () => {
    generation.current++
    setFlow(undefined)
    setBusy(false)
    try {
      await invoke('github:cancelDeviceFlow')
    } catch (error) {
      showToast(error)
    }
  }
  useEffect(
    () => () => {
      generation.current++
      void invoke('github:cancelDeviceFlow').catch(() => undefined)
    },
    []
  )
  const begin = async () => {
    if (busy) return
    const current = ++generation.current
    setBusy(true)
    setError(undefined)
    try {
      const next = await invoke('github:beginDeviceFlow')
      if (current !== generation.current) return
      setFlow(next)
      const account = await invoke('github:completeDeviceFlow')
      if (current !== generation.current) return
      useGitHubStore.getState().setAccount(account)
      setFlow(undefined)
      showToast('github.signedIn')
    } catch (failure) {
      if (current === generation.current) {
        setFlow(undefined)
        setError(failure)
        showToast(failure)
      }
    } finally {
      if (current === generation.current) setBusy(false)
    }
  }
  return (
    <>
      <button type="button" disabled={busy} onClick={() => void begin()}>
        {busy ? t('common.loading') : t('github.signIn')}
      </button>
      <GitHubFailure error={error} />
      {flow &&
        createPortal(
          <Dialog title={t('github.deviceTitle')} onClose={() => void cancel()}>
            <p>{t('github.deviceInstructions')}</p>
            <output className={styles.code} aria-label={t('github.userCode')}>
              {flow.userCode}
            </output>
            <button
              type="button"
              onClick={() =>
                void navigator.clipboard
                  .writeText(flow.userCode)
                  .then(() => showToast('github.copied'))
                  .catch(showToast)
              }
            >
              {t('github.copy')}
            </button>
            <a className={styles.link} href={flow.verificationUri} target="_blank" rel="noreferrer">
              {t('github.openBrowser')}
            </a>
            <p role="status">{t('github.waiting')}</p>
            <button type="button" onClick={() => void cancel()}>
              {t('common.cancel')}
            </button>
          </Dialog>,
          document.body
        )}
    </>
  )
}

/** Preferences account section; also refreshes restored sessions. */
export function GitHubAccountSection() {
  const t = useT()
  const account = useGitHubStore((state) => state.account)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<unknown>()
  useEffect(() => {
    void useGitHubStore.getState().refreshAccount().catch(setError)
  }, [])
  return (
    <fieldset className={styles.section}>
      <legend>{t('github.accountTitle')}</legend>
      {account ? (
        <div className={styles.account}>
          {account.avatarUrl && <img src={account.avatarUrl} alt="" className={styles.avatar} />}
          <span>
            {account.login}
            {account.name ? ` (${account.name})` : ''}
          </span>
          <button
            type="button"
            disabled={busy}
            onClick={() => {
              setBusy(true)
              void useGitHubStore
                .getState()
                .signOut()
                .then(() => showToast('github.signedOut'))
                .catch((error) => {
                  setError(error)
                  showToast(error)
                })
                .finally(() => setBusy(false))
            }}
          >
            {t('github.signOut')}
          </button>
        </div>
      ) : (
        <GitHubSignIn />
      )}
      <GitHubFailure error={error} />
    </fieldset>
  )
}
