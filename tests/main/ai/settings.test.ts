import { mkdir, readFile, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { AiSettingsStore } from '../../../src/main/ai/settings'

const directories: string[] = []
afterEach(async () => {
  await Promise.all(directories.splice(0).map((path) => rm(path, { recursive: true, force: true })))
})
async function setup(available = true) {
  const path = join(process.cwd(), 'tests/main/ai', `.settings-${crypto.randomUUID()}`)
  directories.push(path)
  await mkdir(path)
  const cryptoStorage = {
    isEncryptionAvailable: () => available,
    encryptString: vi.fn((key: string) => Buffer.from(Buffer.from(key).map((byte) => byte ^ 0x55))),
    decryptString: vi.fn((data: Buffer) =>
      Buffer.from(data)
        .map((byte) => byte ^ 0x55)
        .toString()
    ),
  }
  return { store: new AiSettingsStore(path, cryptoStorage), path, cryptoStorage }
}
describe('AI settings', () => {
  it('persists only whitelisted settings and an encrypted key, keeps/clears keys and survives reload', async () => {
    const { store, path, cryptoStorage } = await setup()
    expect(await store.get()).toEqual({ provider: 'none', hasApiKey: false })
    const result = await store.update({
      provider: 'anthropic',
      apiKey: 'secret-value',
      model: 'chosen',
    })
    expect(result).toEqual({ provider: 'anthropic', model: 'chosen', hasApiKey: true })
    expect(JSON.stringify(result)).not.toContain('secret-value')
    expect(await readFile(join(path, 'ai-settings.json'), 'utf8')).not.toContain('secret-value')
    expect((await readFile(join(path, 'ai-key.enc'))).toString()).not.toContain('secret-value')
    const reloaded = new AiSettingsStore(path, cryptoStorage)
    expect(await reloaded.apiKey()).toBe('secret-value')
    await reloaded.update({ provider: 'openai-compatible' })
    expect(await reloaded.apiKey()).toBe('secret-value')
    expect((await reloaded.update({ apiKey: null })).hasApiKey).toBe(false)
    expect(await reloaded.apiKey()).toBeUndefined()
  })
  it('refuses plaintext fallback when encryption is unavailable', async () => {
    const { store, path } = await setup(false)
    await expect(store.update({ apiKey: 'secret-value' })).rejects.toMatchObject({
      kind: 'authentication-failed',
    })
    await expect(readFile(join(path, 'ai-key.enc'))).rejects.toMatchObject({ code: 'ENOENT' })
    expect((await store.get()).hasApiKey).toBe(false)
  })
  it('sanitizes decryption failures and serializes concurrent updates', async () => {
    const { store, cryptoStorage } = await setup()
    await Promise.all([store.update({ apiKey: 'secret-value' }), store.update({ model: 'last' })])
    expect(await store.get()).toMatchObject({ model: 'last', hasApiKey: true })
    cryptoStorage.decryptString.mockImplementation(() => {
      throw new Error('secret-value')
    })
    await expect(store.apiKey()).rejects.toMatchObject({ kind: 'authentication-failed' })
    await expect(store.apiKey()).rejects.not.toThrow('secret-value')
  })
})
