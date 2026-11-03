import { useEffect, useMemo, useState, useSyncExternalStore } from 'react'
import type { Branch } from '@shared/models/git'
import { useT } from '../../i18n'
import { invoke, subscribe } from '../../ipc'
import { fuzzyScore, getCommands, subscribeCommands } from '../../lib/commands'
import { useAppStore, useSelectedRepository } from '../../state/app-store'
import { useDialogStore } from '../../state/dialog-store'
import { usePaletteStore } from '../../state/palette-store'
import { useRepoStore } from '../../state/repo-store'
import { runOperation, synchronize, useSyncStore } from '../../state/sync-store'
import { showToast } from '../../state/toast-store'
import { Dialog } from '../dialogs/Dialog'
import { VirtualList } from '../common/VirtualList'
import {
  openRepositorySettings,
  RepositorySettingsHost,
} from '../repository-settings/RepositorySettingsDialog'
import styles from './CommandPalette.module.css'

interface Entry {
  id: string
  label: string
  shortcut?: string
  run(): void | Promise<void>
}

export function CommandPalette() {
  const { open, show, close } = usePaletteStore()
  const repoId = useAppStore((state) => state.selectedRepositoryId)
  useEffect(() => {
    const off = subscribe('menu:command', (command) => {
      if (command === 'command-palette') show()
    })
    const keydown = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && !event.altKey && event.key.toLowerCase() === 'k') {
        event.preventDefault()
        if (usePaletteStore.getState().open) close()
        else show()
      }
    }
    window.addEventListener('keydown', keydown)
    return () => {
      off()
      window.removeEventListener('keydown', keydown)
    }
  }, [show, close])
  return (
    <>
      <RepositorySettingsHost />
      {open && <Palette key={repoId} onClose={close} />}
    </>
  )
}

function Palette({ onClose }: { onClose(): void }) {
  const t = useT()
  const app = useAppStore()
  const repo = useSelectedRepository()
  const active = useSyncStore((state) => state.active)
  const registered = useSyncExternalStore(subscribeCommands, getCommands)
  const [branches, setBranches] = useState<ReadonlyArray<Branch>>([])
  const [query, setQuery] = useState('')
  const [selected, setSelected] = useState(0)
  const [loading, setLoading] = useState(!!repo)
  useEffect(() => {
    if (!repo) return
    let cancelled = false
    void invoke('git:branches', repo.id)
      .then((items) => {
        if (!cancelled) setBranches(items)
      })
      .catch((error) => {
        if (!cancelled) showToast(error)
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [repo])
  const entries = useMemo(() => {
    const items: Entry[] = app.repositories
      .filter((item) => item.available)
      .map((item) => ({
        id: `repo:${item.id}`,
        label: t('lfs.palette.repository', { name: item.alias ?? item.name }),
        run: () => app.selectRepository(item.id),
      }))
    if (repo && !active) {
      for (const branch of branches.filter((item) => !item.isCurrent))
        items.push({
          id: `branch:${branch.name}`,
          label: t('lfs.palette.branch', { name: branch.name }),
          run: async () => {
            await runOperation(repo.id, (opId) =>
              invoke('git:checkout', repo.id, branch.name, { opId })
            )
            await useRepoStore.getState().refresh()
          },
        })
      for (const command of ['fetch', 'pull', 'push'] as const)
        items.push({
          id: command,
          label: t(`lfs.palette.${command}`),
          shortcut: { fetch: 'Ctrl+Shift+T', pull: 'Ctrl+Shift+P', push: 'Ctrl+P' }[command],
          run: () => synchronize(command),
        })
      items.push({
        id: 'branch',
        label: t('lfs.palette.newBranch'),
        shortcut: 'Ctrl+Shift+N',
        run: () => useDialogStore.getState().open('branch'),
      })
    }
    for (const kind of ['add', 'create', 'clone'] as const)
      items.push({
        id: kind,
        label: t(`lfs.palette.${kind}`),
        shortcut: { add: 'Ctrl+O', create: 'Ctrl+N', clone: 'Ctrl+Shift+O' }[kind],
        run: () => useDialogStore.getState().open(kind),
      })
    for (const tab of ['changes', 'history'] as const)
      items.push({
        id: tab,
        label: t(`lfs.palette.${tab}`),
        shortcut: tab === 'changes' ? 'Ctrl+1' : 'Ctrl+2',
        run: () => app.setTab(tab),
      })
    items.push({
      id: 'preferences',
      label: t('lfs.palette.preferences'),
      shortcut: 'Ctrl+,',
      run: () => app.setPreferencesOpen(true),
    })
    if (repo)
      items.push({
        id: 'settings',
        label: t('lfs.palette.settings'),
        run: () => openRepositorySettings(repo),
      })
    items.push(
      ...registered
        .filter((command) => command.enabled?.() !== false)
        .map((command) => ({ ...command, label: t(command.label) }))
    )
    return items
      .map((item, index) => ({ item, index, score: fuzzyScore(item.label, query) }))
      .filter((match) => match.score !== undefined)
      .sort((a, b) => b.score! - a.score! || a.index - b.index)
      .map((match) => match.item)
  }, [app, repo, active, branches, registered, query, t])
  const index = Math.min(selected, Math.max(0, entries.length - 1))
  const execute = (entry?: Entry) => {
    if (!entry) return
    onClose()
    void Promise.resolve()
      .then(() => entry.run())
      .catch(showToast)
  }
  return (
    <Dialog title={t('lfs.palette.title')} onClose={onClose}>
      <div className={styles.palette}>
        <input
          type="search"
          aria-label={t('lfs.palette.search')}
          value={query}
          aria-describedby="palette-selection"
          onChange={(event) => {
            setQuery(event.target.value)
            setSelected(0)
          }}
          onKeyDown={(event) => {
            if (event.nativeEvent.isComposing) return
            if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
              event.preventDefault()
              setSelected(
                Math.max(
                  0,
                  Math.min(entries.length - 1, index + (event.key === 'ArrowDown' ? 1 : -1))
                )
              )
            } else if (event.key === 'Enter') {
              event.preventDefault()
              execute(entries[index])
            } else if (event.key === 'Escape') {
              event.preventDefault()
              onClose()
            }
          }}
        />
        <span id="palette-selection" className={styles.selection} aria-live="polite">
          {entries[index]?.label}
        </span>
        {loading && <span role="status">{t('common.loading')}</span>}
        {entries.length ? (
          <VirtualList
            items={entries}
            rowHeight={28}
            label={t('lfs.palette.results')}
            selectedIndex={index}
            onSelect={setSelected}
            onActivate={(position) => execute(entries[position])}
            getKey={(entry) => entry.id}
            renderRow={(entry, position) => (
              <button
                type="button"
                tabIndex={-1}
                className={`${styles.row} ${position === index ? styles.selected : ''}`}
                onClick={() => execute(entry)}
              >
                <span>{entry.label}</span>
                <kbd>{entry.shortcut}</kbd>
              </button>
            )}
          />
        ) : (
          <p role="status">{t('lfs.palette.empty')}</p>
        )}
      </div>
    </Dialog>
  )
}
