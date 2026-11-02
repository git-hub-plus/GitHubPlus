import { useEffect, useRef } from 'react'
import type { ThemePreference } from '@shared/models/app'
import type { Language } from '@shared/i18n'
import { useAppStore } from '../state/app-store'
import { useT } from '../i18n'
import styles from './PreferencesDialog.module.css'

const themes: ReadonlyArray<ThemePreference> = ['light', 'dark', 'system']
const languages: ReadonlyArray<{ id: Language; label: string }> = [
  { id: 'ko', label: '한국어' },
  { id: 'en', label: 'English' },
]

/** Language and theme apply immediately; there is nothing to save. */
export function PreferencesDialog() {
  const t = useT()
  const open = useAppStore((s) => s.preferencesOpen)
  const setOpen = useAppStore((s) => s.setPreferencesOpen)
  const settings = useAppStore((s) => s.settings)
  const updateSettings = useAppStore((s) => s.updateSettings)
  const ref = useRef<HTMLDialogElement>(null)

  useEffect(() => {
    const dialog = ref.current
    if (open && dialog && !dialog.open) dialog.showModal()
    if (!open && dialog?.open) dialog.close()
  }, [open])

  return (
    <dialog ref={ref} className={styles.dialog} onClose={() => setOpen(false)}>
      <h1 className={styles.title}>{t('preferences.title')}</h1>
      <label className={styles.field}>
        <span>{t('preferences.language')}</span>
        <select
          value={settings.language}
          onChange={(e) => void updateSettings({ language: e.target.value as Language })}
        >
          {languages.map((l) => (
            <option key={l.id} value={l.id}>
              {l.label}
            </option>
          ))}
        </select>
      </label>
      <fieldset className={styles.field}>
        <legend>{t('preferences.theme')}</legend>
        <div className={styles.choices}>
          {themes.map((theme) => (
            <label key={theme}>
              <input
                type="radio"
                name="theme"
                checked={settings.theme === theme}
                onChange={() => void updateSettings({ theme })}
              />
              {t(`preferences.themes.${theme}`)}
            </label>
          ))}
        </div>
      </fieldset>
      <div className={styles.footer}>
        <button onClick={() => setOpen(false)}>{t('common.close')}</button>
      </div>
    </dialog>
  )
}
