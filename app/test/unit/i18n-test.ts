import assert from 'node:assert/strict'
import { afterEach, describe, it } from 'node:test'
import {
  getLanguage,
  getLocale,
  isLanguage,
  onLanguageChanged,
  setLanguage,
  t,
} from '../../src/lib/i18n'

describe('i18n', () => {
  afterEach(() => setLanguage('ko'))

  it('defaults to Korean and preserves access keys', () => {
    assert.equal(getLanguage(), 'ko')
    assert.equal(getLocale(), 'ko-KR')
    assert.equal(t('menu.labels.fileAccessKey'), '파일(&F)')
  })

  it('switches dictionaries and formatting locales', () => {
    setLanguage('en')
    assert.equal(getLanguage(), 'en')
    assert.equal(getLocale(), 'en-US')
    assert.equal(t('preferences.tabs.appearance'), 'Appearance')
    setLanguage('ko')
    assert.equal(t('preferences.tabs.appearance'), '모양')
    assert.equal(getLocale(), 'ko-KR')
  })

  it('interpolates strings and numbers without interpreting replacement syntax', () => {
    assert.equal(t('hub.pushedBy', { name: '$& {n}' }), '$& {n}님이 푸시함')
    assert.equal(
      t('preferences.appearance.defaultTabSize', { n: 4 }),
      '4 (기본값)'
    )
    assert.equal(t('hub.pushedBy'), '{name}님이 푸시함')
    assert.equal(t('hub.pushedBy', { other: 'unused' }), '{name}님이 푸시함')
    setLanguage('en')
    assert.equal(t('hub.pushedBy', { name: 'Snow' }), 'Pushed by Snow')
  })

  it('notifies only for changes and supports unsubscribing', () => {
    const changes: string[] = []
    const unsubscribe = onLanguageChanged(() => changes.push(getLanguage()))
    try {
      setLanguage('ko')
      setLanguage('en')
      setLanguage('en')
      setLanguage('ko')
      assert.deepEqual(changes, ['en', 'ko'])
      unsubscribe()
      setLanguage('en')
      assert.deepEqual(changes, ['en', 'ko'])
    } finally {
      unsubscribe()
    }
  })

  it('accepts only supported language values', () => {
    for (const value of ['ko', 'en']) {
      assert.equal(isLanguage(value), true)
    }
    for (const value of ['ja', 'ko-KR', '', null, undefined, 1, {}]) {
      assert.equal(isLanguage(value), false)
    }
  })
})
