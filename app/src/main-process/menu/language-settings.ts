import { app } from 'electron'
import { readFileSync } from 'fs'
import { mkdir, writeFile, rename } from 'fs/promises'
import { join } from 'path'
import { getLanguage, isLanguage, Language, setLanguage } from '../../lib/i18n'

let initialized = false

function getSettingsPath() {
  return join(app.getPath('userData'), 'i18n-settings.json')
}

/** Load once, synchronously, before the first native menu is constructed. */
export function initializeMenuLanguageSync(): void {
  if (initialized) {
    return
  }
  initialized = true
  try {
    const settings: unknown = JSON.parse(
      readFileSync(getSettingsPath(), 'utf8')
    )
    if (
      typeof settings === 'object' &&
      settings !== null &&
      'language' in settings &&
      isLanguage(settings.language)
    ) {
      setLanguage(settings.language)
    }
  } catch (error) {
    if (error.code !== 'ENOENT') {
      log.warn('Unable to read app language settings; using Korean', error)
    }
  }
}

/** Persist before notifying either process; use rename to avoid partial JSON. */
export async function saveMenuLanguage(language: Language): Promise<Language> {
  if (!isLanguage(language)) {
    throw new Error('Unsupported app language')
  }
  const path = getSettingsPath()
  await mkdir(app.getPath('userData'), { recursive: true })
  await writeFile(`${path}.tmp`, JSON.stringify({ language }), 'utf8')
  await rename(`${path}.tmp`, path)
  setLanguage(language)
  return getLanguage()
}
