import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { TokenStore } from '../../../src/main/github/token-store'

describe('GitHub token storage', () => {
  const directories: string[] = []
  afterEach(async () => {
    await Promise.all(
      directories.splice(0).map((path) => rm(path, { recursive: true, force: true }))
    )
  })

  async function location() {
    const path = await mkdtemp(join(tmpdir(), 'ghp-github-token-'))
    directories.push(path)
    return join(path, 'github-token')
  }

  it('encrypts, reloads and deletes a credential with injected safeStorage', async () => {
    const path = await location()
    const safe = {
      isEncryptionAvailable: () => true,
      encryptString: vi.fn((_value: string) => Buffer.from('ciphertext')),
      decryptString: vi.fn((_value: Buffer) => 'private-token'),
    }
    const tokens = new TokenStore(path, safe)
    await tokens.set('private-token')
    expect(safe.encryptString).toHaveBeenCalledWith('private-token')
    expect((await readFile(path)).toString()).not.toContain('private-token')
    const restored = new TokenStore(path, safe)
    await restored.load()
    expect(restored.get()).toBe('private-token')
    await restored.clear()
    expect(restored.get()).toBeUndefined()
    await expect(readFile(path)).rejects.toMatchObject({ code: 'ENOENT' })
  })

  it('keeps credentials only in memory and warns when encryption is unavailable', async () => {
    const path = await location()
    const warn = vi.fn()
    const safe = {
      isEncryptionAvailable: () => false,
      encryptString: vi.fn(),
      decryptString: vi.fn(),
    }
    const tokens = new TokenStore(path, safe, warn)
    await tokens.set('private-token')
    expect(tokens.get()).toBe('private-token')
    expect(safe.encryptString).not.toHaveBeenCalled()
    expect(warn).toHaveBeenCalled()
    expect(JSON.stringify(warn.mock.calls)).not.toContain('private-token')
    await expect(readFile(path)).rejects.toMatchObject({ code: 'ENOENT' })
  })

  it('does not decrypt a saved credential when encryption is unavailable', async () => {
    const path = await location()
    await writeFile(path, 'ciphertext')
    const safe = {
      isEncryptionAvailable: () => false,
      encryptString: vi.fn(),
      decryptString: vi.fn(),
    }
    const tokens = new TokenStore(path, safe, vi.fn())
    await tokens.load()
    expect(tokens.get()).toBeUndefined()
    expect(safe.decryptString).not.toHaveBeenCalled()
  })

  it('removes memory and disk credentials when sign-out races an unfinished save', async () => {
    const path = await location()
    const safe = {
      isEncryptionAvailable: () => true,
      encryptString: (_value: string) => Buffer.from('ciphertext'),
      decryptString: (_value: Buffer) => 'private-token',
    }
    const tokens = new TokenStore(path, safe)
    const saving = tokens.set('private-token')
    const clearing = tokens.clear()
    await Promise.all([saving, clearing])
    expect(tokens.get()).toBeUndefined()
    await expect(readFile(path)).rejects.toMatchObject({ code: 'ENOENT' })
  })
})
