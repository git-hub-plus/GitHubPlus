import { useEffect, useMemo, useRef } from 'react'
import {
  DiffLineType,
  type DiffLine,
  type DiffSelectionData,
  type FileDiff,
} from '@shared/models/diff'
import { isSelected, withRangeSelection, withSelectableLines } from '@shared/models/diff-selection'
import { t } from '@shared/i18n'
import { VirtualList } from '../common/VirtualList'
import styles from './DiffView.module.css'

export interface DiffViewProps {
  readonly diff: FileDiff
  /** Path shown in the header. */
  readonly path: string
  /**
   * When set, lines can be (de)selected for the next commit (changes view).
   * Omit for read-only diffs (history view).
   */
  readonly selection?: DiffSelectionData
  readonly onSelectionChange?: (selection: DiffSelectionData) => void
}

type Row = { key: string; line: DiffLine } | { key: string; header: string; lines: number[] }

export function DiffView({ diff, path, selection, onSelectionChange }: DiffViewProps) {
  const rows = useMemo(() => {
    const result: Row[] = []
    if (diff.kind !== 'text' && diff.kind !== 'large') return result
    diff.hunks.forEach((hunk, index) => {
      const lines = hunk.lines
        .filter(
          (line) =>
            (line.type === DiffLineType.Add || line.type === DiffLineType.Delete) &&
            line.originalLineNumber !== null
        )
        .map((line) => line.originalLineNumber!)
      const h = hunk.header
      result.push({
        key: `h${index}`,
        header: `@@ -${h.oldStartLine},${h.oldLineCount} +${h.newStartLine},${h.newLineCount} @@`,
        lines,
      })
      hunk.lines.forEach((line, offset) => {
        if (line.type !== DiffLineType.Hunk) result.push({ key: `${index}:${offset}`, line })
      })
    })
    return result
  }, [diff])
  const selectable = useMemo(
    () => rows.flatMap((row) => ('header' in row ? row.lines : [])),
    [rows]
  )
  const normalized = useMemo(
    () => (selection ? withSelectableLines(selection, selectable) : undefined),
    [selection, selectable]
  )
  useEffect(() => {
    if (
      normalized &&
      selection &&
      (diff.kind === 'text' || diff.kind === 'large') &&
      JSON.stringify(normalized) !== JSON.stringify(selection)
    )
      onSelectionChange?.(normalized)
  }, [normalized, selection, onSelectionChange, diff.kind])
  const drag = useRef<{ from: number; selected: boolean; base: DiffSelectionData } | null>(null)
  useEffect(() => {
    const stop = () => {
      drag.current = null
    }
    window.addEventListener('pointerup', stop)
    window.addEventListener('pointercancel', stop)
    return () => {
      window.removeEventListener('pointerup', stop)
      window.removeEventListener('pointercancel', stop)
    }
  }, [])
  const toggle = (lines: number[]) => {
    if (!normalized || !lines.length) return
    const selected = !lines.every((line) => isSelected(normalized, line))
    onSelectionChange?.(
      lines.reduce((next, line) => withRangeSelection(next, line, 1, selected), normalized)
    )
  }
  let content
  if (diff.kind === 'text' || diff.kind === 'large') {
    content = (
      <VirtualList
        items={rows}
        rowHeight={26}
        getKey={(row) => row.key}
        renderRow={(row) => {
          if ('header' in row)
            return (
              <button
                type="button"
                className={styles.hunk}
                disabled={!normalized || !onSelectionChange || !row.lines.length}
                aria-label={t('changesView.toggleHunk', { header: row.header })}
                onClick={() => toggle(row.lines)}
              >
                {row.header}
              </button>
            )
          const { line } = row
          const change = line.type === DiffLineType.Add || line.type === DiffLineType.Delete
          const number = line.originalLineNumber
          const interactive = !!normalized && !!onSelectionChange && change && number !== null
          const selected = !!normalized && number !== null && isSelected(normalized, number)
          return (
            <div
              className={`${styles.line} ${line.type === DiffLineType.Add ? styles.add : line.type === DiffLineType.Delete ? styles.del : ''} ${interactive && selected ? styles.selected : ''}`}
            >
              <button
                type="button"
                className={styles.numbers}
                disabled={!interactive}
                aria-label={t('changesView.toggleLine', { line: number ?? '' })}
                aria-pressed={interactive ? selected : undefined}
                onClick={(event) => {
                  if (event.detail === 0 && number !== null) toggle([number])
                }}
                onPointerDown={(event) => {
                  if (event.button !== 0 || !interactive || number === null || !normalized) return
                  event.preventDefault()
                  event.currentTarget.focus()
                  drag.current = { from: number, selected: !selected, base: normalized }
                  onSelectionChange?.(withRangeSelection(normalized, number, 1, !selected))
                }}
                onPointerEnter={() => {
                  const active = drag.current
                  if (active && interactive && number !== null)
                    onSelectionChange?.(
                      withRangeSelection(
                        active.base,
                        Math.min(active.from, number),
                        Math.abs(active.from - number) + 1,
                        active.selected
                      )
                    )
                }}
              >
                <span>{line.oldLineNumber ?? ''}</span>
                <span>{line.newLineNumber ?? ''}</span>
              </button>
              <code className={styles.code}>{line.text}</code>
            </div>
          )
        }}
      />
    )
  } else if (diff.kind === 'image') {
    content = (
      <div className={styles.images}>
        {(['previous', 'current'] as const).map((side) => (
          <figure key={side}>
            <figcaption>{t(`changesView.${side}`)}</figcaption>
            {diff[side] ? (
              <img
                alt={t(`changesView.${side}`)}
                src={`data:${diff[side].mediaType};base64,${diff[side].contents}`}
              />
            ) : (
              <p>{t('changesView.noImage')}</p>
            )}
          </figure>
        ))}
      </div>
    )
  } else if (diff.kind === 'submodule') {
    content = (
      <div className={styles.message}>
        <p>{t('changesView.submodule')}</p>
        <code>
          {diff.oldSha ?? '—'} → {diff.newSha ?? '—'}
        </code>
        <p>{diff.url}</p>
      </div>
    )
  } else
    content = (
      <p className={styles.message}>
        {t(diff.kind === 'binary' ? 'changesView.binary' : 'changesView.unrenderable')}
      </p>
    )
  return (
    <section className={styles.root} data-testid="diff-view" aria-label={path}>
      <header className={styles.header}>{path}</header>
      {content}
    </section>
  )
}
