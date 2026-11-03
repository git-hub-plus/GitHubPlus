import { readFile, writeFile, mkdir, rename, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { HandlerError } from '@shared/errors'
import type { AiIpc, AiSettings } from '@shared/ipc/integrations'

type CryptoStorage = {
  isEncryptionAvailable(): boolean
  encryptString(value: string): Buffer
  decryptString(value: Buffer): string
}
type SettingsPatch = Parameters<AiIpc['ai:updateSettings']>[0]
export class AiSettingsStore {
  private queue: Promise<unknown> = Promise.resolve()
  constructor(
    private readonly directory: string,
    private readonly crypto: CryptoStorage
  ) {}
  private async readOptional(name: string): Promise<Buffer | undefined> {
    try {
      return await readFile(join(this.directory, name))
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === 'ENOENT') return undefined
      throw error
    }
  }
  private async write(name: string, value: string | Buffer): Promise<void> {
    await mkdir(this.directory, { recursive: true })
    const path = join(this.directory, name)
    await writeFile(`${path}.tmp`, value, { mode: 0o600 })
    await rename(`${path}.tmp`, path)
  }
  async get(): Promise<AiSettings> {
    try {
      const data = await this.readOptional('ai-settings.json')
      const saved = data ? (JSON.parse(data.toString('utf8')) as Partial<AiSettings>) : {}
      return {
        provider:
          saved.provider === 'anthropic' || saved.provider === 'openai-compatible'
            ? saved.provider
            : 'none',
        model: typeof saved.model === 'string' ? saved.model : undefined,
        baseUrl: typeof saved.baseUrl === 'string' ? saved.baseUrl : undefined,
        hasApiKey: Boolean(await this.readOptional('ai-key.enc')),
      }
    } catch {
      throw new HandlerError('internal', 'Could not read AI settings.')
    }
  }
  async apiKey(): Promise<string | undefined> {
    try {
      const encrypted = await this.readOptional('ai-key.enc')
      if (!encrypted) return undefined
      if (!this.crypto.isEncryptionAvailable()) throw new Error()
      return this.crypto.decryptString(encrypted)
    } catch {
      throw new HandlerError(
        'authentication-failed',
        'Could not unlock the AI API key. Save it again.'
      )
    }
  }
  update(patch: SettingsPatch): Promise<AiSettings> {
    const operation = this.queue.then(async () => {
      if (
        patch.provider !== undefined &&
        !['none', 'anthropic', 'openai-compatible'].includes(patch.provider)
      )
        throw new HandlerError('invalid-argument', 'Unknown AI provider.')
      if (
        (patch.model !== undefined && typeof patch.model !== 'string') ||
        (patch.baseUrl !== undefined && typeof patch.baseUrl !== 'string') ||
        (patch.apiKey !== undefined && patch.apiKey !== null && typeof patch.apiKey !== 'string')
      )
        throw new HandlerError('invalid-argument', 'Invalid AI settings.')
      const current = await this.get()
      try {
        if (patch.apiKey === null || patch.apiKey === '')
          await rm(join(this.directory, 'ai-key.enc'), { force: true })
        else if (patch.apiKey !== undefined) {
          if (!this.crypto.isEncryptionAvailable())
            throw new HandlerError(
              'authentication-failed',
              'Secure API key storage is unavailable.'
            )
          await this.write('ai-key.enc', this.crypto.encryptString(patch.apiKey))
        }
        // Whitelist fields: never serialize apiKey or arbitrary IPC properties.
        await this.write(
          'ai-settings.json',
          JSON.stringify({
            provider: patch.provider ?? current.provider,
            model: patch.model ?? current.model,
            baseUrl: patch.baseUrl ?? current.baseUrl,
          })
        )
        return await this.get()
      } catch (error) {
        if (error instanceof HandlerError) throw error
        throw new HandlerError('internal', 'Could not save AI settings.')
      }
    })
    this.queue = operation.catch(() => undefined)
    return operation
  }
}
