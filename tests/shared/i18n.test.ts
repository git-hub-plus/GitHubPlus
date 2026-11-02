import { afterEach, describe, expect, it, vi } from 'vitest'
import { getLanguage, getLocale, onLanguageChanged, setLanguage, t } from '@shared/i18n'

describe('i18n', () => {
  afterEach(() => setLanguage('ko'))

  it('defaults to Korean', () => {
    expect(getLanguage()).toBe('ko')
    expect(t('workspace.changes')).toBe('변경 사항')
  })

  it('switches language and locale', () => {
    setLanguage('en')
    expect(t('workspace.changes')).toBe('Changes')
    expect(getLocale()).toBe('en-US')
  })

  it('interpolates parameters and keeps unknown placeholders', () => {
    expect(t('toolbar.pull', { count: 3 })).toBe('풀 3')
    expect(t('toolbar.pull')).toBe('풀 {count}')
  })

  it('notifies subscribers only on real changes', () => {
    const listener = vi.fn()
    const unsubscribe = onLanguageChanged(listener)
    setLanguage('ko')
    setLanguage('en')
    unsubscribe()
    setLanguage('ko')
    expect(listener).toHaveBeenCalledTimes(1)
  })
})
