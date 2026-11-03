import { useEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import type { AiCommitFilesInput } from '@shared/ipc/integrations'
import { invoke } from '../../ipc'
import { useT } from '../../i18n'
import { useAiStore } from '../../state/ai-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import styles from './Ai.module.css'

export function AiCommitButton({
  repoId,
  input,
  disabled,
  onGenerated,
}: {
  repoId: string
  input: AiCommitFilesInput
  disabled: boolean
  onGenerated(message: { summary: string; description: string }): void
}) {
  const t = useT()
  const settings = useAiStore((state) => state.settings)
  const [busy, setBusy] = useState(false)
  const [preview, setPreview] = useState<{ payload: string; input: AiCommitFilesInput }>()
  const pending = useRef(false)
  const mounted = useRef(true)
  useEffect(() => {
    mounted.current = true
    // Yield the first turn to the primary changes/diff loading work. Optional
    // provider settings should not compete with opening the repository view.
    const timer = window.setTimeout(() => {
      void useAiStore.getState().load().catch(showToast)
    }, 0)
    return () => {
      window.clearTimeout(timer)
      mounted.current = false
    }
  }, [])
  const prepare = async () => {
    if (pending.current) return
    pending.current = true
    setBusy(true)
    try {
      const payload = await invoke('ai:previewPayload', repoId, input)
      if (mounted.current) setPreview({ payload, input })
    } catch (error) {
      showToast(error)
    } finally {
      pending.current = false
      if (mounted.current) setBusy(false)
    }
  }
  const send = async () => {
    if (!preview || pending.current) return
    pending.current = true
    setBusy(true)
    try {
      // Recheck immediately before sending: a filesystem edit may have occurred
      // while the user was reading the preview. Show the new text for approval.
      const payload = await invoke('ai:previewPayload', repoId, preview.input)
      if (payload !== preview.payload) {
        if (mounted.current) setPreview({ ...preview, payload })
        return
      }
      const message = await invoke('ai:generateCommitMessage', repoId, preview.input)
      if (mounted.current) {
        onGenerated(message)
        setPreview(undefined)
      }
    } catch (error) {
      showToast(error)
    } finally {
      pending.current = false
      if (mounted.current) setBusy(false)
    }
  }
  if (!settings || settings.provider === 'none') return null
  return (
    <>
      <button type="button" disabled={disabled || busy} onClick={() => void prepare()}>
        {busy ? t('ai.generating') : t('ai.write')}
      </button>
      {preview &&
        createPortal(
          <div
            onSubmit={(event) => event.stopPropagation()}
            onKeyDown={(event) => event.stopPropagation()}
          >
            <Dialog
              title={t('ai.previewTitle')}
              onClose={() => setPreview(undefined)}
              onSubmit={() => void send()}
              submitLabel={t('ai.send')}
              busy={busy}
            >
              <p>{t('ai.previewHelp')}</p>
              <pre className={styles.preview} tabIndex={0}>
                {preview.payload}
              </pre>
            </Dialog>
          </div>,
          document.body
        )}
    </>
  )
}
