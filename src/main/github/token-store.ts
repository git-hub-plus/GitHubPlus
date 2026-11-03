import { mkdir, readFile, rm, writeFile } from 'node:fs/promises'
import { dirname } from 'node:path'

export interface SecretStorage {
  isEncryptionAvailable(): boolean
  encryptString(value: string): Buffer
  decryptString(value: Buffer): string
}

/** Secrets never leave this main-process cache as IPC data or error details. */
export class TokenStore {
  private token: string | undefined
  private pending: Promise<void> = Promise.resolve()
  public constructor(
    private readonly filePath: string,
    private readonly storage: SecretStorage,
    private readonly warn: (message: string) => void = () => undefined
  ) {}

  public get(): string | undefined {
    return this.token
  }

  public async load(): Promise<void> {
    if (!this.storage.isEncryptionAvailable()) {
      this.warn('GitHub 토큰 암호화를 사용할 수 없어 메모리에서만 로그인합니다')
      await rm(this.filePath, { force: true })
      return
    }
    try {
      this.token = this.storage.decryptString(await readFile(this.filePath))
    } catch {
      this.token = undefined
      await rm(this.filePath, { force: true })
    }
  }

  public async set(token: string): Promise<void> {
    this.token = token
    return this.enqueue(() => this.persist(token))
  }

  private enqueue(operation: () => Promise<void>): Promise<void> {
    const next = this.pending.then(operation)
    this.pending = next.catch(() => undefined)
    return next
  }

  private async persist(token: string): Promise<void> {
    if (!this.storage.isEncryptionAvailable()) {
      await rm(this.filePath, { force: true })
      this.warn('GitHub 토큰을 저장하지 않았습니다. 앱 종료 시 로그아웃됩니다')
      return
    }
    try {
      const encrypted = this.storage.encryptString(token)
      await mkdir(dirname(this.filePath), { recursive: true })
      await writeFile(this.filePath, encrypted, { mode: 0o600 })
    } catch {
      await rm(this.filePath, { force: true })
      this.warn('GitHub 토큰을 저장하지 못했습니다. 앱 종료 시 로그아웃됩니다')
    }
  }

  public async clear(): Promise<void> {
    this.token = undefined
    await this.enqueue(() => rm(this.filePath, { force: true }))
  }
}
