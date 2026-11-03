import { useCallback, useEffect, useMemo, useRef, useState, type MouseEvent } from 'react'
import type { Commit, GitProgress } from '@shared/models/git'
import type { OperationOutcome } from '@shared/ipc/git-advanced'
import { GhpError } from '@shared/errors'
import { invoke, subscribe } from '../../ipc'
import { useT } from '../../i18n'
import { useAppStore } from '../../state/app-store'
import { useChangesStore } from '../../state/changes-store'
import { useHistoryStore } from '../../state/history-store'
import { useRepoStore } from '../../state/repo-store'
import { showToast } from '../../state/toast-store'
import { ContextMenu } from '../common/ContextMenu'
import { Dialog } from '../dialogs/Dialog'
import { historyPolicy, reorderPlan } from './history-policy'
import styles from './HistoryActions.module.css'

type Action =
  | { kind: 'revert'; sha: string }
  | { kind: 'undo' }
  | { kind: 'tag'; sha: string }
  | { kind: 'deleteTag'; name: string }
  | { kind: 'squash'; shas: string[] }
  | { kind: 'rebase' }
  | { kind: 'reorder'; shas: string[]; afterSha: string | null }
type Menu = { x: number; y: number; items: { label: string; onSelect(): void }[] }

export function useHistoryActions(repoId: string | undefined) {
  const t = useT()
  const state = useHistoryStore()
  const policy = useMemo(
    () => historyPolicy(state.commits, state.branches),
    [state.commits, state.branches]
  )
  const [menu, setMenu] = useState<Menu>()
  const [action, setAction] = useState<Action>()
  const [message, setMessage] = useState('')
  const [name, setName] = useState('')
  const [remote, setRemote] = useState('')
  const [deleteRemote, setDeleteRemote] = useState(false)
  const [busy, setBusy] = useState(false)
  const [progress, setProgress] = useState<GitProgress>()
  const [error, setError] = useState<unknown>()
  const lock = useRef(false)
  const operation = useRef<string | undefined>(undefined)
  const dragged = useRef<string[]>([])
  const alive = useRef(true)
  useEffect(() => {
    alive.current = true
    return () => {
      alive.current = false
    }
  }, [])
  useEffect(
    () =>
      subscribe('git:progress', (event) => {
        if (event.opId === operation.current) setProgress(event.progress)
      }),
    []
  )
  const closeMenu = useCallback(() => setMenu(undefined), [])
  const open = (next: Action) => {
    if (lock.current) return
    setError(undefined)
    setName(
      next.kind === 'rebase' ? (state.branches.find((branch) => !branch.isCurrent)?.name ?? '') : ''
    )
    setMessage(
      next.kind === 'squash'
        ? next.shas
            .map((sha) => state.commits.find((commit) => commit.sha === sha)?.summary ?? '')
            .join('\n\n')
        : ''
    )
    setRemote(state.branches.find((branch) => branch.type === 'remote')?.remoteName ?? '')
    setDeleteRemote(false)
    setAction(next)
  }
  const run = async (work: () => Promise<OperationOutcome | void>, undo = false) => {
    if (!repoId || lock.current) return
    const origin = repoId
    lock.current = true
    setBusy(true)
    setError(undefined)
    setProgress(undefined)
    operation.current = crypto.randomUUID()
    try {
      const result = await work()
      showToast(
        result === 'conflicts'
          ? 'historyActions.conflicts'
          : result === 'nothing-to-do'
            ? 'historyActions.nothing'
            : 'historyActions.success',
        result === 'conflicts' ? 'error' : 'success'
      )
      if (alive.current && useAppStore.getState().selectedRepositoryId === origin)
        setAction(undefined)
      if (useAppStore.getState().selectedRepositoryId === origin) {
        await useRepoStore.getState().refresh()
        if (useHistoryStore.getState().repoId === origin)
          await useHistoryStore.getState().load(true)
        if (undo && useAppStore.getState().selectedRepositoryId === origin)
          useAppStore.getState().setTab('changes')
      }
    } catch (failure) {
      if (alive.current && useAppStore.getState().selectedRepositoryId === origin) setError(failure)
      showToast(failure)
      if (useAppStore.getState().selectedRepositoryId === origin)
        await useRepoStore.getState().refresh()
    } finally {
      lock.current = false
      operation.current = undefined
      if (alive.current) {
        setBusy(false)
        setProgress(undefined)
      }
    }
  }
  const title = action ? t(`historyActions.${action.kind}`) : ''
  const remotes = [
    ...new Set(state.branches.flatMap((branch) => (branch.remoteName ? [branch.remoteName] : []))),
  ]
  const commitMenu = (event: MouseEvent, commit: Commit) => {
    event.preventDefault()
    event.stopPropagation()
    if (lock.current) return
    const shas = state.selectedShas.includes(commit.sha) ? state.selectedShas : [commit.sha]
    if (!state.selectedShas.includes(commit.sha)) state.choose(commit.sha)
    const ordered = state.commits
      .filter((item) => shas.includes(item.sha))
      .map((item) => item.sha)
      .reverse()
    const items: Menu['items'] = []
    if (shas.length === 1) {
      items.push({
        label: t('historyActions.revert'),
        onSelect: () => open({ kind: 'revert', sha: commit.sha }),
      })
      items.push({
        label: t('historyActions.tag'),
        onSelect: () => open({ kind: 'tag', sha: commit.sha }),
      })
      items.push({
        label: t('historyActions.copy'),
        onSelect: () => {
          void navigator.clipboard
            .writeText(commit.sha)
            .then(() => showToast('historyActions.copied'), showToast)
        },
      })
      if (policy.current?.tipSha === commit.sha)
        items.push({ label: t('historyActions.undo'), onSelect: () => open({ kind: 'undo' }) })
    }
    if (
      policy.current &&
      policy.currentComplete &&
      shas.every((sha) => !policy.currentShas.has(sha) && policy.otherShas.has(sha))
    )
      items.push({
        label: t('historyActions.cherryPick'),
        onSelect: () => {
          void run(() => invoke('git:cherryPick', repoId!, ordered))
        },
      })
    if (shas.length > 1 && shas.every((sha) => policy.path.includes(sha)))
      items.push({
        label: t('historyActions.squash'),
        onSelect: () => {
          const orderedPath = policy.path.filter((sha) => shas.includes(sha)).reverse()
          const positions = orderedPath.map((sha) => policy.path.indexOf(sha))
          if (Math.max(...positions) - Math.min(...positions) + 1 !== shas.length) {
            showToast('historyActions.contiguous', 'error')
            return
          }
          if (
            policy.path
              .slice(0, Math.max(...positions) + 1)
              .some((sha) => policy.published.has(sha))
          ) {
            showToast('historyActions.published', 'error')
            return
          }
          if (!policy.remoteBoundaryKnown) {
            showToast('historyActions.unknownPush', 'error')
            return
          }
          open({ kind: 'squash', shas: orderedPath })
        },
      })
    if (items.length) setMenu({ x: event.clientX, y: event.clientY, items })
  }
  const rebaseMenu = (event: MouseEvent) => {
    event.preventDefault()
    event.stopPropagation()
    if (!lock.current)
      setMenu({
        x: event.clientX,
        y: event.clientY,
        items: [{ label: t('historyActions.rebase'), onSelect: () => open({ kind: 'rebase' }) }],
      })
  }
  const tagMenu = (event: MouseEvent, tag: string) => {
    event.preventDefault()
    event.stopPropagation()
    if (lock.current) return
    setMenu({
      x: event.clientX,
      y: event.clientY,
      items: [
        {
          label: t('historyActions.deleteTag'),
          onSelect: () => open({ kind: 'deleteTag', name: tag }),
        },
        {
          label: t('historyActions.pushTag'),
          onSelect: () => {
            void run(() => invoke('git:pushTag', repoId!, tag, { opId: operation.current! }))
          },
        },
      ],
    })
  }
  const drop = (afterSha: string | null) => {
    const shas = dragged.current
    dragged.current = []
    if (lock.current) return
    if (shas.length && afterSha === null && !policy.completePath) {
      showToast('historyActions.loadOlder', 'error')
      return
    }
    const plan = reorderPlan(policy.path, shas, afterSha)
    if (!plan) return
    if (plan.rewritten.some((sha) => policy.published.has(sha))) {
      showToast('historyActions.published', 'error')
      return
    }
    // With an unseen remote tip we cannot establish the rewrite boundary safely.
    if (!policy.remoteBoundaryKnown) {
      showToast('historyActions.unknownPush', 'error')
      return
    }
    open({ kind: 'reorder', shas: plan.shas, afterSha: plan.afterSha })
  }
  const submit = () => {
    if (!action || !repoId) return
    void run(async () => {
      switch (action.kind) {
        case 'revert':
          return invoke('git:revert', repoId, action.sha)
        case 'undo': {
          const draft = await invoke('git:undoLastCommit', repoId)
          useChangesStore.getState().setMessageDraft(repoId, draft)
          return
        }
        case 'tag':
          return invoke('git:createTag', repoId, {
            name: name.trim(),
            sha: action.sha,
            ...(message.trim() ? { message } : {}),
          })
        case 'deleteTag':
          return invoke('git:deleteTag', repoId, action.name, deleteRemote ? { remote } : undefined)
        case 'squash':
          return invoke('git:squash', repoId, { shas: action.shas, message })
        case 'rebase':
          return invoke('git:rebase', repoId, name, { opId: operation.current })
        case 'reorder':
          return invoke('git:reorder', repoId, { shas: action.shas, afterSha: action.afterSha })
      }
    }, action.kind === 'undo')
  }
  const errorKind = error instanceof GhpError ? error.kind : 'internal'
  const errorView = error !== undefined && (
    <div role="alert" className={styles.error}>
      {t(
        errorKind === 'push-rejected' || errorKind === 'hub-history-protected'
          ? 'historyActions.undoRejected'
          : errorKind === 'local-changes-overwritten'
            ? 'historyActions.localChanges'
            : errorKind === 'network'
              ? 'historyActions.network'
              : 'historyActions.failed'
      )}
      <details>
        <summary>{t('common.details')}</summary>
        <pre>
          {error instanceof GhpError ? `${error.message}\n${error.detail ?? ''}` : String(error)}
        </pre>
      </details>
    </div>
  )
  return {
    busy,
    canRebase: !busy && !!policy.current && state.branches.some((branch) => !branch.isCurrent),
    commitMenu,
    rebaseMenu,
    tagMenu,
    rebase: () => open({ kind: 'rebase' }),
    dragStart(sha: string) {
      dragged.current = state.selectedShas.includes(sha) ? [...state.selectedShas] : [sha]
    },
    dragEnd() {
      dragged.current = []
    },
    canDrag: (sha: string) => !busy && policy.path.includes(sha),
    drop,
    moveOldest() {
      dragged.current = [...state.selectedShas]
      drop(null)
    },
    ui: (
      <>
        {menu && <ContextMenu {...menu} onClose={closeMenu} />}
        {busy && (
          <div role="status" className={styles.status}>
            {t('historyActions.working')}
            {progress && (
              <>
                <progress
                  aria-label={t('historyActions.progress')}
                  max={1}
                  value={progress.value}
                />
                <span>{progress.description ?? progress.title}</span>
              </>
            )}
          </div>
        )}
        {!action && errorView}
        {action && (
          <Dialog
            title={title}
            onClose={() => setAction(undefined)}
            onSubmit={submit}
            submitLabel={t('common.ok')}
            busy={busy}
            disabled={
              ((action.kind === 'tag' || action.kind === 'rebase') && !name.trim()) ||
              (action.kind === 'squash' && !message.trim()) ||
              (action.kind === 'deleteTag' && deleteRemote && !remote)
            }
          >
            <div className={styles.fields}>
              {(action.kind === 'revert' ||
                action.kind === 'undo' ||
                action.kind === 'reorder') && <p>{t(`historyActions.confirm.${action.kind}`)}</p>}
              {action.kind === 'revert' && <code>{action.sha}</code>}
              {action.kind === 'reorder' && (
                <code>
                  {action.shas.join(', ')} → {action.afterSha ?? t('historyActions.oldest')}
                </code>
              )}
              {action.kind === 'tag' && (
                <label>
                  {t('historyActions.name')}
                  <input required value={name} onChange={(event) => setName(event.target.value)} />
                </label>
              )}
              {(action.kind === 'tag' || action.kind === 'squash') && (
                <label>
                  {t('historyActions.message')}
                  <textarea
                    rows={5}
                    value={message}
                    onChange={(event) => setMessage(event.target.value)}
                  />
                </label>
              )}
              {action.kind === 'rebase' && (
                <>
                  <p>{t('historyActions.rebaseHelp')}</p>
                  <label>
                    {t('historyActions.target')}
                    <select value={name} onChange={(event) => setName(event.target.value)}>
                      <option value="">{t('historyActions.chooseBranch')}</option>
                      {state.branches
                        .filter((branch) => !branch.isCurrent)
                        .map((branch) => (
                          <option key={`${branch.type}:${branch.name}`} value={branch.name}>
                            {branch.name}
                          </option>
                        ))}
                    </select>
                  </label>
                </>
              )}
              {action.kind === 'deleteTag' && (
                <>
                  <p>{t('historyActions.deleteTagConfirm', { name: action.name })}</p>
                  <label className={styles.checkbox}>
                    <input
                      type="checkbox"
                      checked={deleteRemote}
                      onChange={(event) => setDeleteRemote(event.target.checked)}
                    />
                    {t('historyActions.deleteRemote')}
                  </label>
                  {deleteRemote && (
                    <label>
                      {t('historyActions.remote')}
                      <input
                        list="history-tag-remotes"
                        value={remote}
                        onChange={(event) => setRemote(event.target.value)}
                      />
                      <datalist id="history-tag-remotes">
                        {remotes.map((item) => (
                          <option key={item} value={item} />
                        ))}
                      </datalist>
                    </label>
                  )}
                </>
              )}
              {errorView}
            </div>
          </Dialog>
        )}
      </>
    ),
  }
}
