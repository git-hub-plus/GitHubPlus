import assert from 'node:assert'
import { describe, it } from 'node:test'
import { reportError } from '../../src/main-process/exception-reporting'

describe('local error reporting', () => {
  it('logs fatal and non-fatal errors without requests', async t => {
    const fetch = t.mock.method(globalThis, 'fetch')
    const errorLog = t.mock.method(log, 'error')
    const error = new Error('test error')
    await reportError(error)
    await reportError(error, { context: 'test' }, true)
    assert.strictEqual(errorLog.mock.callCount(), 2)
    assert.strictEqual(errorLog.mock.calls[0].arguments[1], error)
    assert.strictEqual(fetch.mock.callCount(), 0)
  })
})
