import { useEffect } from 'react'
import { useAppStore } from './state/app-store'
import { useAppliedTheme } from './hooks/use-applied-theme'
import { Sidebar } from './components/Sidebar'
import { Toolbar } from './components/Toolbar'
import { Workspace } from './components/Workspace'
import { PreferencesDialog } from './components/PreferencesDialog'
import { subscribe } from './ipc'
import styles from './App.module.css'

export function App() {
  const ready = useAppStore((s) => s.ready)
  const init = useAppStore((s) => s.init)
  const language = useAppStore((s) => s.settings.language)
  useAppliedTheme()

  useEffect(() => {
    void init()
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
      }),
    []
  )

  if (!ready) {
    return null
  }

  return (
    <div className={styles.shell}>
      <Sidebar />
      <div className={styles.main}>
        <Toolbar />
        <Workspace />
      </div>
      <PreferencesDialog />
    </div>
  )
}
