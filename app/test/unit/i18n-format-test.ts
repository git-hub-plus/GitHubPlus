import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'
import { setLanguage } from '../../src/lib/i18n'
import { formatDate } from '../../src/lib/format-date'
import { formatRelative } from '../../src/lib/format-relative'
import { formatNumber } from '../../src/lib/format-number'
import {
  setDateFormatPreference,
  setNumberFormatPreference,
} from '../../src/models/formatting-preferences'

describe('localized formatting', () => {
  let storage: string
  beforeEach(() => {
    storage = JSON.stringify({ ...localStorage })
    localStorage.clear()
  })
  afterEach(() => {
    localStorage.clear()
    for (const [key, value] of Object.entries<string>(JSON.parse(storage))) {
      localStorage.setItem(key, value)
    }
    setLanguage('ko')
  })

  it('updates month names and relative dates after a language change', () => {
    setDateFormatPreference('MMMM do, yyyy')
    const date = new Date(2026, 0, 2, 14, 30)
    setLanguage('ko')
    assert.equal(formatDate(date, { time: false }), '1월 2일, 2026')
    assert.equal(formatRelative(-86400000), '어제')
    setLanguage('en')
    assert.equal(formatDate(date, { time: false }), 'January 2nd, 2026')
    assert.equal(formatRelative(-86400000), 'yesterday')
    setLanguage('ko')
    assert.equal(formatRelative(-86400000), '어제')
  })

  it('uses the app number locale while preserving explicit formatting preferences', () => {
    for (const language of ['ko', 'en'] as const) {
      setLanguage(language)
      assert.equal(formatNumber(1234567.89), '1,234,567.89')
      assert.equal(formatNumber(0.000001), '0.000001')
    }
    setNumberFormatPreference({
      thousandsSeparator: '.',
      decimalSeparator: ',',
    })
    assert.equal(formatNumber(1234567.89), '1.234.567,89')
    setLanguage('en')
    assert.equal(formatNumber(1234567.89), '1.234.567,89')
  })
})
