import { t as translate, type TranslationKey } from '@shared/i18n'
import { useAppStore } from './state/app-store'

/**
 * Returns `t` bound to the current language. Components re-render when the
 * language setting changes because they subscribe to it here.
 */
export function useT(): (key: TranslationKey, params?: Record<string, string | number>) => string {
  useAppStore((s) => s.settings.language)
  return translate
}
