// Ported from GitHub Desktop (MIT): app/src/lib/status-parser.ts
import {
  AppFileStatusKind as Kind,
  UnmergedEntrySummary as Conflict,
  type AppFileStatus,
} from '@shared/models/status'

export interface IStatusEntry {
  readonly kind: 'entry'
  readonly path: string
  readonly statusCode: string
  readonly submoduleStatusCode: string
  readonly oldPath?: string
  readonly renameOrCopyScore?: number
}
export interface IStatusHeader {
  readonly kind: 'header'
  readonly value: string
}
export const isStatusHeader = (item: IStatusEntry | IStatusHeader): item is IStatusHeader =>
  item.kind === 'header'
export const isStatusEntry = (item: IStatusEntry | IStatusHeader): item is IStatusEntry =>
  item.kind === 'entry'

/** Consume only metadata fields, preserving whitespace and Unicode in NUL-delimited paths. */
export function parsePorcelainStatus(output: Buffer | string): Array<IStatusEntry | IStatusHeader> {
  const tokens = output.toString().split('\0')
  const entries: Array<IStatusEntry | IStatusHeader> = []
  for (let i = 0; i < tokens.length; i++) {
    const field = tokens[i]
    if (field.startsWith('# ')) {
      entries.push({ kind: 'header', value: field.slice(2) })
      continue
    }
    if (field.startsWith('? ')) {
      entries.push({
        kind: 'entry',
        path: field.slice(2),
        statusCode: '??',
        submoduleStatusCode: '????',
      })
      continue
    }
    const type = field[0]
    if (!['1', '2', 'u'].includes(type)) continue
    const count = type === '1' ? 8 : type === '2' ? 9 : 10
    let offset = 0
    const parts: string[] = []
    for (let n = 0; n < count; n++) {
      const end = field.indexOf(' ', offset)
      if (end < 0) throw new Error('Malformed porcelain status record')
      parts.push(field.slice(offset, end))
      offset = end + 1
    }
    const oldPath = type === '2' ? tokens[++i] : undefined
    if (type === '2' && !oldPath) throw new Error('Missing rename source path')
    entries.push({
      kind: 'entry',
      path: field.slice(offset),
      statusCode: parts[1],
      submoduleStatusCode: parts[2],
      oldPath,
      renameOrCopyScore: type === '2' ? Number(parts[8].slice(1)) : undefined,
    })
  }
  return entries
}
const conflicts: Record<string, Conflict> = {
  DD: Conflict.BothDeleted,
  AU: Conflict.AddedByUs,
  UD: Conflict.DeletedByThem,
  UA: Conflict.AddedByThem,
  DU: Conflict.DeletedByUs,
  AA: Conflict.BothAdded,
  UU: Conflict.BothModified,
}

export function mapStatus(
  statusCode: string,
  submoduleStatusCode = 'N...',
  renameOrCopyScore?: number,
  oldPath?: string
): AppFileStatus {
  const submoduleStatus = submoduleStatusCode.startsWith('S')
    ? {
        commitChanged: submoduleStatusCode[1] === 'C',
        modifiedChanges: submoduleStatusCode[2] === 'M',
        untrackedChanges: submoduleStatusCode[3] === 'U',
      }
    : undefined
  if (conflicts[statusCode])
    return { kind: Kind.Conflicted, action: conflicts[statusCode], submoduleStatus }
  if (statusCode === '??') return { kind: Kind.Untracked, submoduleStatus }
  if (oldPath !== undefined && /[RC]/.test(statusCode))
    return {
      kind: statusCode.includes('R') ? Kind.Renamed : Kind.Copied,
      oldPath,
      renameIncludesModifications:
        statusCode.includes('M') || (renameOrCopyScore !== undefined && renameOrCopyScore < 100),
      submoduleStatus,
    }
  return {
    kind: statusCode.includes('A')
      ? Kind.New
      : statusCode === 'D.' || statusCode === '.D'
        ? Kind.Deleted
        : Kind.Modified,
    submoduleStatus,
  }
}
