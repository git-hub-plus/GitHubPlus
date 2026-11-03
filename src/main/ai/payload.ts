import { HandlerError } from '@shared/errors'
import type { AiCommitFilesInput } from '@shared/ipc/integrations'
import { getSelectionType, isSelectable, isSelected } from '@shared/models/diff-selection'
import { DiffLineType, type FileDiff } from '@shared/models/diff'
import type { WorkingFile } from '@shared/models/status'
import { getWorkingDiff, validatePath } from '../git/diff'
import { formatPatch } from '../git/patch-formatter'
import { getStatus } from '../git/status'

export const FILE_LIMIT = 4000
export const TOTAL_LIMIT = 24000
export const TRUNCATED = '\n(이하 생략)'
function truncate(text: string, limit: number): string {
  return text.length > limit
    ? text.slice(0, Math.max(0, limit - TRUNCATED.length)) + TRUNCATED
    : text
}
interface PayloadDependencies {
  files(path: string): Promise<ReadonlyArray<WorkingFile>>
  diff(path: string, file: WorkingFile): Promise<FileDiff>
}
const defaults: PayloadDependencies = {
  files: async (path) => (await getStatus(path)).files,
  diff: getWorkingDiff,
}
export async function buildPayload(
  repoPath: string,
  input: AiCommitFilesInput,
  dependencies = defaults
): Promise<string> {
  const files = await dependencies.files(repoPath)
  const sections: string[] = []
  for (const requested of input.files) {
    validatePath(repoPath, requested.path)
    if (getSelectionType(requested.selection) === 'none') continue
    const file = files.find((candidate) => candidate.path === requested.path)
    if (!file) throw new HandlerError('not-found', 'A selected file is no longer changed.')
    const diff = await dependencies.diff(repoPath, file)
    let section: string
    if (diff.kind === 'text' || diff.kind === 'large') {
      const selected = diff.hunks.some((hunk) =>
        hunk.lines.some(
          (line) =>
            (line.type === DiffLineType.Add || line.type === DiffLineType.Delete) &&
            line.originalLineNumber !== null &&
            isSelectable(requested.selection, line.originalLineNumber) &&
            isSelected(requested.selection, line.originalLineNumber)
        )
      )
      if (!selected) continue
      section = formatPatch({ ...file, selection: requested.selection }, diff)
    } else {
      // Never send image base64, binary contents, URLs or other metadata.
      section = file.path
    }
    sections.push(truncate(section, FILE_LIMIT))
    if (sections.join('\n\n').length > TOTAL_LIMIT) break
  }
  const payload = truncate(sections.join('\n\n'), TOTAL_LIMIT)
  if (!payload)
    throw new HandlerError('invalid-argument', 'Select changes before generating a commit message.')
  return payload
}
