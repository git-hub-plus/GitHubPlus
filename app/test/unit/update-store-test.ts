import assert from 'node:assert'
import { describe, it } from 'node:test'
import { updateStore, UpdateStatus } from '../../src/ui/lib/update-store'

describe('disabled updates', () => {
  it('keeps every update entry point idle without network requests', async t => {
    const fetch = t.mock.method(globalThis, 'fetch')
    let changed = 0
    const subscription = updateStore.onDidChange(state => {
      assert.strictEqual(state.status, UpdateStatus.UpdateNotAvailable)
      changed++
    })
    try {
      await updateStore.checkForUpdates(true, false)
      await updateStore.checkForUpdates(false, true)
      updateStore.quitAndInstallUpdate()
      updateStore.setPrioritizeUpdate(true)
      updateStore.setPrioritizeUpdateInfoUrl('https://example.com')
      updateStore.setIsx64ToARM64ImmediateAutoUpdate(true)
      assert.strictEqual(await updateStore.isUpdateShowcase(), false)
      assert.deepStrictEqual(updateStore.state, {
        status: UpdateStatus.UpdateNotAvailable,
        lastSuccessfulCheck: null,
        newReleases: null,
        isX64ToARM64ImmediateAutoUpdate: false,
        prioritizeUpdate: false,
        prioritizeUpdateInfoUrl: undefined,
      })
      assert.strictEqual(changed, 2)
      assert.strictEqual(fetch.mock.callCount(), 0)
    } finally {
      subscription.dispose()
    }
  })
})
