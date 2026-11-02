// Ported from GitHub Desktop (MIT): app/src/lib/git/clone.ts
import { dirname, isAbsolute } from 'node:path'
import { mkdir } from 'node:fs/promises'
import { HandlerError } from '@shared/errors'
import type { CloneInput } from '@shared/ipc/git'
import { runWithProgress, type ProgressCallback } from './progress/from-process'

export async function clone(input: CloneInput, progress?: ProgressCallback): Promise<void> {
  if (!isAbsolute(input.path))
    throw new HandlerError('unknown', 'Clone destination must be absolute')
  const parent = dirname(input.path)
  await mkdir(parent, { recursive: true })
  await runWithProgress(
    [
      'clone',
      '--progress',
      ...(input.branch ? ['--branch', input.branch] : []),
      '--',
      input.url,
      input.path,
    ],
    parent,
    'clone',
    'Cloning',
    progress
  )
}
