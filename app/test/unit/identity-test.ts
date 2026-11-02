import assert from 'node:assert'
import { describe, it } from 'node:test'
import { getBundleID, getProductName } from '../../package-info'
import { getReplacements } from '../../app-info'
import {
  getExecutableName,
  getWindowsIdentifierName,
} from '../../../script/dist-info'

describe('GitHub+ identity', () => {
  for (const mode of ['development', 'production']) {
    it(`isolates ${mode} names and OAuth configuration`, () => {
      const keys = [
        'NODE_ENV',
        'RELEASE_CHANNEL',
        'DESKTOP_OAUTH_CLIENT_ID',
        'DESKTOP_OAUTH_CLIENT_SECRET',
      ]
      const previous = keys.map(key => process.env[key])
      try {
        process.env.NODE_ENV = mode
        process.env.RELEASE_CHANNEL = mode
        delete process.env.DESKTOP_OAUTH_CLIENT_ID
        delete process.env.DESKTOP_OAUTH_CLIENT_SECRET
        const dev = mode === 'development'
        assert.strictEqual(getProductName(), dev ? 'GitHub+-dev' : 'GitHub+')
        assert.strictEqual(
          getBundleID(),
          `com.devsnowflake.githubplus${dev ? 'Dev' : ''}`
        )
        assert.strictEqual(getWindowsIdentifierName(), 'GitHubPlus')
        if (process.platform === 'win32') {
          assert.strictEqual(
            getExecutableName(),
            dev ? 'GitHubPlus-dev' : 'GitHubPlus'
          )
        }
        const replacements = getReplacements()
        assert.strictEqual(replacements.__DEV_SECRETS__, dev)
        assert.strictEqual('__UPDATES_URL__' in replacements, false)
        assert.strictEqual(
          '__ERROR_REPORTING_ENDPOINT__' in replacements,
          false
        )
        assert.strictEqual(
          '__NON_FATAL_ERROR_REPORTING_ENDPOINT__' in replacements,
          false
        )
        if (dev) {
          assert.ok(JSON.parse(replacements.__OAUTH_CLIENT_ID__).length > 0)
          assert.ok(JSON.parse(replacements.__OAUTH_SECRET__).length > 0)
        }
        if (!dev) {
          assert.strictEqual(
            replacements.__OAUTH_CLIENT_ID__,
            JSON.stringify('')
          )
          assert.strictEqual(replacements.__OAUTH_SECRET__, JSON.stringify(''))
        }
        process.env.DESKTOP_OAUTH_CLIENT_ID = 'test-client'
        process.env.DESKTOP_OAUTH_CLIENT_SECRET = 'test-secret'
        assert.strictEqual(
          getReplacements().__OAUTH_CLIENT_ID__,
          JSON.stringify('test-client')
        )
        assert.strictEqual(
          getReplacements().__OAUTH_SECRET__,
          JSON.stringify('test-secret')
        )
      } finally {
        keys.forEach((key, index) => {
          const value = previous[index]
          if (value === undefined) {
            delete process.env[key]
          } else {
            process.env[key] = value
          }
        })
      }
    })
  }
})
