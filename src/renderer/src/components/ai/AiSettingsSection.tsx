import { useEffect, useState } from 'react'
import type { AiProvider } from '@shared/ipc/integrations'
import { useAiStore } from '../../state/ai-store'
import { showToast } from '../../state/toast-store'
import { useT } from '../../i18n'
import styles from './Ai.module.css'

export function AiSettingsSection() {
  const t = useT()
  const settings = useAiStore((state) => state.settings)
  const [provider, setProvider] = useState<AiProvider>('none')
  const [model, setModel] = useState('')
  const [baseUrl, setBaseUrl] = useState('')
  const [apiKey, setApiKey] = useState('')
  const [busy, setBusy] = useState(false)
  const [saved, setSaved] = useState(false)
  const [adoptedSettings, setAdoptedSettings] = useState<typeof settings>()
  useEffect(() => {
    void useAiStore.getState().load().catch(showToast)
  }, [])
  if (settings && settings !== adoptedSettings) {
    setAdoptedSettings(settings)
    setProvider(settings.provider)
    setModel(settings.model ?? '')
    setBaseUrl(settings.baseUrl ?? '')
  }
  const save = async (clearKey = false) => {
    if (busy) return
    setBusy(true)
    setSaved(false)
    try {
      await useAiStore.getState().update({
        provider,
        model: model.trim(),
        baseUrl: baseUrl.trim(),
        ...(clearKey ? { apiKey: null } : apiKey ? { apiKey } : {}),
      })
      setApiKey('')
      setSaved(true)
    } catch (error) {
      showToast(error)
    } finally {
      setBusy(false)
    }
  }
  return (
    <section className={styles.settings} aria-labelledby="ai-settings-heading">
      <h3 id="ai-settings-heading">{t('ai.title')}</h3>
      <label htmlFor="ai-provider">{t('ai.provider')}</label>
      <select
        id="ai-provider"
        value={provider}
        disabled={busy || !settings}
        onChange={(event) => {
          setProvider(event.target.value as AiProvider)
          setModel('')
          setSaved(false)
        }}
      >
        <option value="none">{t('ai.none')}</option>
        <option value="anthropic">{t('ai.anthropic')}</option>
        <option value="openai-compatible">{t('ai.openaiCompatible')}</option>
      </select>
      {provider !== 'none' && (
        <>
          <label htmlFor="ai-model">{t('ai.model')}</label>
          <input
            id="ai-model"
            value={model}
            disabled={busy}
            list={provider === 'anthropic' ? 'ai-models' : undefined}
            placeholder={provider === 'anthropic' ? 'claude-opus-5-5' : undefined}
            onChange={(event) => setModel(event.target.value)}
          />
          <datalist id="ai-models">
            <option value="claude-opus-5-5" />
            <option value="claude-sonnet-5-5" />
            <option value="claude-haiku-5-5" />
          </datalist>
          {provider === 'openai-compatible' && (
            <>
              <label htmlFor="ai-base-url">{t('ai.baseUrl')}</label>
              <input
                id="ai-base-url"
                type="url"
                value={baseUrl}
                disabled={busy}
                onChange={(event) => setBaseUrl(event.target.value)}
              />
            </>
          )}
          <label htmlFor="ai-api-key">{t('ai.apiKey')}</label>
          <input
            id="ai-api-key"
            type="password"
            autoComplete="new-password"
            value={apiKey}
            disabled={busy}
            placeholder={settings?.hasApiKey ? t('ai.saved') : undefined}
            onChange={(event) => setApiKey(event.target.value)}
          />
          {settings?.hasApiKey && (
            <button type="button" disabled={busy} onClick={() => void save(true)}>
              {t('ai.clearKey')}
            </button>
          )}
        </>
      )}
      <div className={styles.actions}>
        <button type="button" disabled={busy || !settings} onClick={() => void save()}>
          {t('ai.save')}
        </button>
        {saved && <span role="status">{t('ai.saved')}</span>}
      </div>
    </section>
  )
}
