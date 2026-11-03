import { useEffect, useMemo, useState } from 'react'
import { AppFileStatusKind, type WorkingFile } from '@shared/models/status'
import { invoke } from '../../ipc'
import { LargeFileHint, type LargeFileCandidate } from '../repository-settings/LargeFileHint'

/** Looks up sizes of new files so the LFS hint can suggest tracking large ones. */
export function NewLargeFilesHint({
  repoId,
  files,
}: {
  repoId: string
  files: ReadonlyArray<WorkingFile>
}) {
  const newPaths = useMemo(
    () =>
      files
        .filter(
          (file) =>
            file.status.kind === AppFileStatusKind.New ||
            file.status.kind === AppFileStatusKind.Untracked
        )
        .map((file) => file.path),
    [files]
  )
  const key = newPaths.join('\n')
  const [result, setResult] = useState<{ key: string; files: LargeFileCandidate[] }>()

  useEffect(() => {
    if (!newPaths.length) return
    let current = true
    invoke('files:sizes', repoId, newPaths)
      .then((sizes) => {
        if (!current) return
        setResult({
          key,
          files: newPaths.flatMap((path, index) => {
            const size = sizes[index]
            return size === null || size === undefined ? [] : [{ path, size, isNew: true }]
          }),
        })
      })
      .catch(() => undefined)
    return () => {
      current = false
    }
  }, [repoId, key, newPaths])

  if (!newPaths.length || result?.key !== key) return null
  return <LargeFileHint repoId={repoId} files={result.files} />
}
