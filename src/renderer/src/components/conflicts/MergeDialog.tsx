import { useState } from 'react'
import { useT } from '../../i18n'
import { invoke } from '../../ipc'
import { useRepoStore } from '../../state/repo-store'
import { performOperation, useOperationStore } from '../../state/operation-store'
import { Dialog } from '../dialogs/Dialog'

export function MergeDialog({
  repoId,
  branch,
  onClose,
}: {
  repoId: string
  branch: string
  onClose(): void
}) {
  const t = useT()
  const [squash, setSquash] = useState(false)
  const current = useRepoStore((s) => (s.repoId === repoId ? s.status?.currentBranch : undefined))
  const busy = useOperationStore((s) => !!s.busy[repoId])
  return (
    <Dialog
      title={t('conflicts.mergeTitle')}
      submitLabel={t('conflicts.merge')}
      busy={busy}
      disabled={!current}
      onClose={onClose}
      onSubmit={() => {
        void performOperation(repoId, () => invoke('git:merge', repoId, branch, { squash })).then(
          (ok) => {
            if (ok) onClose()
          }
        )
      }}
    >
      <p>{t('conflicts.mergeDirection', { source: branch, target: current ?? '' })}</p>
      <label>
        <input type="checkbox" checked={squash} onChange={(e) => setSquash(e.target.checked)} />
        {t('conflicts.squash')}
      </label>
    </Dialog>
  )
}
