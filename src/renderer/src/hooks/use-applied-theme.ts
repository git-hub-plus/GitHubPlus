import { useEffect } from 'react'
import { useAppStore } from '../state/app-store'

/** Applies the theme preference to `<html data-theme>`, following the OS when "system". */
export function useAppliedTheme(): void {
  const theme = useAppStore((s) => s.settings.theme)

  useEffect(() => {
    const media = window.matchMedia('(prefers-color-scheme: dark)')
    const apply = () => {
      const resolved = theme === 'system' ? (media.matches ? 'dark' : 'light') : theme
      document.documentElement.dataset.theme = resolved
    }
    apply()
    media.addEventListener('change', apply)
    return () => media.removeEventListener('change', apply)
  }, [theme])
}
