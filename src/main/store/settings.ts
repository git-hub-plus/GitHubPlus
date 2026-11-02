import { join } from 'node:path'
import { app } from 'electron'
import type { AppSettings } from '@shared/models/app'
import { isLanguage, setLanguage } from '@shared/i18n'
import { readJson, writeJson } from './json-file'

const defaults: AppSettings = { language: 'ko', theme: 'system' }

let current: AppSettings = defaults
const listeners = new Set<(settings: AppSettings) => void>()

function settingsPath(): string {
  return join(app.getPath('userData'), 'settings.json')
}

function sanitize(value: Partial<AppSettings>): AppSettings {
  return {
    language: isLanguage(value.language) ? value.language : defaults.language,
    theme: value.theme === 'light' || value.theme === 'dark' ? value.theme : 'system',
    defaultRepositoryDirectory:
      typeof value.defaultRepositoryDirectory === 'string'
        ? value.defaultRepositoryDirectory
        : undefined,
  }
}

/** Loads settings before the first window and menu are created. */
export async function loadSettings(): Promise<AppSettings> {
  current = sanitize(await readJson<Partial<AppSettings>>(settingsPath(), {}))
  setLanguage(current.language)
  return current
}

export function getSettings(): AppSettings {
  return current
}

export async function updateSettings(patch: Partial<AppSettings>): Promise<AppSettings> {
  current = sanitize({ ...current, ...patch })
  setLanguage(current.language)
  await writeJson(settingsPath(), current)
  for (const listener of listeners) {
    listener(current)
  }
  return current
}

export function onSettingsChanged(listener: (settings: AppSettings) => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}
