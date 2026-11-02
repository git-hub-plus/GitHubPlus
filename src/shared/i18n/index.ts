import { ko } from './locales/ko'
import { en } from './locales/en'

export type Language = 'ko' | 'en'

type StringValues<T> = {
  readonly [K in keyof T]: T[K] extends string ? string : StringValues<T[K]>
}

export type Translations = StringValues<typeof ko>

type DotPaths<T> = {
  [K in keyof T & string]: T[K] extends string ? K : `${K}.${DotPaths<T[K]>}`
}[keyof T & string]

export type TranslationKey = DotPaths<typeof ko>

let language: Language = 'ko'
const listeners = new Set<() => void>()

/** Return whether a value is a supported app language. */
export function isLanguage(value: unknown): value is Language {
  return value === 'ko' || value === 'en'
}

/** Return the current app language (Korean by default). */
export function getLanguage(): Language {
  return language
}

/** Return the formatting locale for the current app language. */
export function getLocale(): 'ko-KR' | 'en-US' {
  return language === 'ko' ? 'ko-KR' : 'en-US'
}

/** Update this process's language and notify subscribers when it changes. */
export function setLanguage(value: Language): void {
  if (!isLanguage(value) || language === value) {
    return
  }
  language = value
  for (const listener of listeners) {
    listener()
  }
}

/** Subscribe to language changes; the returned function unsubscribes. */
export function onLanguageChanged(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

/** Translate a dot path, preserving placeholders for missing parameters. */
export function t(
  key: TranslationKey,
  params: Readonly<Record<string, string | number>> = {}
): string {
  let value: string | { readonly [key: string]: unknown } = language === 'ko' ? ko : en
  for (const part of key.split('.')) {
    const next: unknown = typeof value === 'string' ? undefined : value[part]
    if (typeof next !== 'string' && (typeof next !== 'object' || next === null)) {
      return key
    }
    value = next as string | { readonly [key: string]: unknown }
  }
  return typeof value === 'string'
    ? value.replace(/\{(\w+)\}/g, (placeholder, name: string) =>
        Object.prototype.hasOwnProperty.call(params, name) ? String(params[name]) : placeholder
      )
    : key
}
