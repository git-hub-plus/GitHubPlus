import { useState } from 'react'
import { AppFileStatusKind } from '@shared/models/status'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { useAppStore } from '../../state/app-store'
import { useRepoStore } from '../../state/repo-store'
import { performOperation, useOperationStore } from '../../state/operation-store'
import { Dialog } from '../dialogs/Dialog'
import styles from './ConflictControls.module.css'

export function InProgressBanner() {
  const repoId = useAppStore((s) => s.selectedRepositoryId)
  return repoId ? <RepositoryBanner key={repoId} repoId={repoId} /> : null
}
function RepositoryBanner({ repoId }: { repoId: string }) {
  const t = useT()
  const status = useRepoStore((s) => (s.repoId === repoId ? s.status : undefined))
  const busy = useOperationStore((s) => !!s.busy[repoId])
  const [dialog, setDialog] = useState<'continue' | 'abort'>()
  const [message, setMessage] = useState('')
  const op = status?.inProgress
  const count =
    status?.files.filter((f) => f.status.kind === AppFileStatusKind.Conflicted).length ?? 0
  if (!op && !count) return null
  const title = !op
    ? t('conflicts.title')
    : op.kind === 'merge'
      ? t('conflicts.mergeProgress', { branch: op.theirBranch ?? '' })
      : op.kind === 'rebase'
        ? t('conflicts.rebaseProgress', {
            branch: op.targetBranch,
            step: op.step,
            total: op.totalSteps,
          })
        : op.kind === 'cherry-pick'
          ? t('conflicts.cherryProgress', { step: op.step, total: op.totalSteps })
          : t('conflicts.revertProgress')
  const next = () =>
    performOperation(repoId, () =>
      invoke(
        'git:continueOperation',
        repoId,
        op?.kind === 'merge' ? { message: message.trim() } : undefined
      )
    )
  return (
    <>
      <div className={styles.bar} role="status">
        <span>
          {title} — {t('conflicts.remaining', { count })}
        </span>
        {op && (
          <>
            <button
              disabled={busy || count > 0}
              onClick={() => {
                if (op.kind === 'merge') setDialog('continue')
                else void next()
              }}
            >
              {t('conflicts.continue')}
            </button>
            <button disabled={busy} onClick={() => setDialog('abort')}>
              {t('conflicts.abort')}
            </button>
          </>
        )}
      </div>
      {dialog && (
        <Dialog
          title={t(dialog === 'abort' ? 'conflicts.abort' : 'conflicts.continue')}
          busy={busy}
          disabled={dialog === 'continue' && (!message.trim() || count > 0)}
          submitLabel={t(dialog === 'abort' ? 'conflicts.abort' : 'conflicts.continue')}
          onClose={() => setDialog(undefined)}
          onSubmit={() => {
            void (
              dialog === 'abort'
                ? performOperation(repoId, () => invoke('git:abortOperation', repoId))
                : next()
            ).then((ok) => {
              if (ok) setDialog(undefined)
            })
          }}
        >
          {dialog === 'abort' ? (
            <p>{t('conflicts.abortConfirm')}</p>
          ) : (
            <label>
              {t('conflicts.message')}
              <input value={message} onChange={(e) => setMessage(e.target.value)} />
            </label>
          )}
        </Dialog>
      )}
    </>
  )
}
