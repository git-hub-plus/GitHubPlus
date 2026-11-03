import { useState } from 'react'
import type { ConflictedFileStatus } from '@shared/models/status'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { performOperation, useOperationStore } from '../../state/operation-store'
import { Dialog } from '../dialogs/Dialog'
import styles from './ConflictControls.module.css'
export function ConflictFileActions({
  repoId,
  path,
  status,
  compact = false,
}: {
  repoId: string
  path: string
  compact?: boolean
  status: ConflictedFileStatus
}) {
  const t = useT()
  const [expanded, setExpanded] = useState(false)
  const [confirm, setConfirm] = useState(false)
  const busy = useOperationStore((s) => !!s.busy[repoId])
  const mark = () => performOperation(repoId, () => invoke('git:markResolved', repoId, [path]))
  if (compact)
    return (
      <>
        <button
          disabled={busy}
          onClick={(e) => {
            e.stopPropagation()
            setExpanded(true)
          }}
        >
          {t('conflicts.title')}
        </button>
        {expanded && (
          <Dialog
            title={`${t('conflicts.title')} ${path}`}
            busy={busy}
            onClose={() => setExpanded(false)}
          >
            <ConflictFileActions repoId={repoId} path={path} status={status} />
          </Dialog>
        )}
      </>
    )
  return (
    <div
      className={styles.actions}
      role="group"
      aria-label={`${t('conflicts.title')} ${path}`}
      onClick={(e) => e.stopPropagation()}
      onKeyDown={(e) => {
        if (e.key === 'Enter' || e.key === ' ') e.stopPropagation()
      }}
    >
      <button
        disabled={busy}
        onClick={() =>
          void performOperation(repoId, () => invoke('git:resolveConflict', repoId, path, 'ours'))
        }
      >
        {t('conflicts.ours')}
      </button>
      <button
        disabled={busy}
        onClick={() =>
          void performOperation(repoId, () => invoke('git:resolveConflict', repoId, path, 'theirs'))
        }
      >
        {t('conflicts.theirs')}
      </button>
      {status.conflictMarkerCount !== undefined && (
        <>
          <span className={styles.warning}>
            {t('conflicts.markers', { count: status.conflictMarkerCount })}
          </span>
          <button
            disabled={busy}
            onClick={() => {
              if (status.conflictMarkerCount) setConfirm(true)
              else void mark()
            }}
          >
            {t('conflicts.resolved')}
          </button>
        </>
      )}
      {confirm && (
        <div role="alert">
          <p>{t('conflicts.markerWarning')}</p>
          <button disabled={busy} onClick={() => setConfirm(false)}>
            {t('common.close')}
          </button>
          <button
            disabled={busy}
            onClick={() => {
              void mark().then((ok) => {
                if (ok) setConfirm(false)
              })
            }}
          >
            {t('common.ok')}
          </button>
        </div>
      )}
    </div>
  )
}
