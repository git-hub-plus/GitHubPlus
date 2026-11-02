import assert from 'node:assert/strict'
import { afterEach, before, describe, it, mock } from 'node:test'
import { join } from 'path'
import { getLanguage, setLanguage } from '../../../src/lib/i18n'

const userData = join(process.cwd(), 'test-user-data')
const path = join(userData, 'i18n-settings.json')
const read = mock.fn(() => '{"language":"en"}')
const operations: unknown[][] = []
let failWrite = false

mock.restoreAll()
mock.module('electron', {
  namedExports: { app: { getPath: () => userData } },
})
mock.module('fs', { namedExports: { readFileSync: read } })
mock.module('fs/promises', {
  namedExports: {
    mkdir: async (...args: unknown[]) => {
      operations.push(['mkdir', ...args])
    },
    writeFile: async (...args: unknown[]) => {
      operations.push(['write', ...args])
      if (failWrite) {
        throw new Error('Disk unavailable')
      }
    },
    rename: async (...args: unknown[]) => {
      operations.push(['rename', ...args])
    },
  },
})

describe('language settings', () => {
  let settings: typeof import('../../../src/main-process/menu/language-settings')
  before(async () => {
    settings = await import('../../../src/main-process/menu/language-settings')
  })
  afterEach(() => {
    setLanguage('ko')
    operations.length = 0
    failWrite = false
  })

  it('loads the saved language before menu construction and reads only once', () => {
    // Menu startup must finish reading settings before constructing labels.
    // eslint-disable-next-line no-sync
    settings.initializeMenuLanguageSync()
    assert.equal(getLanguage(), 'en')
    // eslint-disable-next-line no-sync
    settings.initializeMenuLanguageSync()
    assert.equal(read.mock.callCount(), 1)
  })

  it('writes complete JSON under userData before changing the language', async () => {
    assert.equal(await settings.saveMenuLanguage('en'), 'en')
    assert.equal(getLanguage(), 'en')
    assert.deepEqual(operations, [
      ['mkdir', userData, { recursive: true }],
      ['write', `${path}.tmp`, '{"language":"en"}', 'utf8'],
      ['rename', `${path}.tmp`, path],
    ])
  })

  it('keeps the current language if persistence fails', async () => {
    failWrite = true
    await assert.rejects(settings.saveMenuLanguage('en'), /Disk unavailable/)
    assert.equal(getLanguage(), 'ko')
    assert.equal(
      operations.some(operation => operation[0] === 'rename'),
      false
    )
  })
})
