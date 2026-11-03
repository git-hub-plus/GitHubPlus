import { useEffect } from 'react'
import { useAppStore } from './state/app-store'
import { useAppliedTheme } from './hooks/use-applied-theme'
import { Sidebar } from './components/Sidebar'
import { Toolbar } from './components/Toolbar'
import { Workspace } from './components/Workspace'
import { PreferencesDialog } from './components/PreferencesDialog'
import { subscribe } from './ipc'
import { startRepoStatusUpdates } from './state/repo-store'
import { useDialogStore } from './state/dialog-store'
import { synchronize } from './state/sync-store'
import { showToast } from './state/toast-store'
import { useShortcuts } from './hooks/use-shortcuts'
import { RepositoryDialogs } from './components/dialogs/RepositoryDialogs'
import { Toasts } from './components/common/Toasts'
import { DropZone } from './components/dropzone/DropZone'
import { CommandPalette } from './components/command-palette/CommandPalette'
import styles from './App.module.css'

export function App() {
  const ready = useAppStore((s) => s.ready)
  const init = useAppStore((s) => s.init)
  const language = useAppStore((s) => s.settings.language)
  useAppliedTheme()
  useShortcuts()

  useEffect(() => {
    void init().then(startRepoStatusUpdates).catch(showToast)
  }, [init])

  useEffect(() => {
    document.documentElement.lang = language
  }, [language])

  useEffect(
    () =>
      subscribe('menu:command', (command) => {
        const store = useAppStore.getState()
        if (command === 'open-preferences') store.setPreferencesOpen(true)
        else if (command === 'show-changes') store.setTab('changes')
        else if (command === 'show-history') store.setTab('history')
        else if (command === 'add-repository') useDialogStore.getState().open('add')
        else if (command === 'create-repository') useDialogStore.getState().open('create')
        else if (command === 'clone-repository') useDialogStore.getState().open('clone')
        else if (command === 'new-branch') useDialogStore.getState().open('branch')
        else if (command === 'about') useDialogStore.getState().open('about')
        else if (command === 'fetch' || command === 'pull' || command === 'push')
          void synchronize(command)
      }),
    []
  )

  if (!ready) {
    return <Toasts />
  }

  return (
    <div className={styles.shell}>
      <Sidebar />
      <div className={styles.main}>
        <Toolbar />
        <Workspace />
      </div>
      <PreferencesDialog />
      <RepositoryDialogs />
      <DropZone />
      <CommandPalette />
      <Toasts />
    </div>
  )
}
