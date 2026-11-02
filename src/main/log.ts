import { appendFile, mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { app } from 'electron'

type Level = 'debug' | 'info' | 'warn' | 'error'

function format(level: Level, message: string, extra: unknown[]): string {
  const details = extra
    .map((e) => (e instanceof Error ? (e.stack ?? e.message) : JSON.stringify(e)))
    .join(' ')
  return `${new Date().toISOString()} ${level.toUpperCase()} ${message}${details ? ' ' + details : ''}\n`
}

let logDirReady: Promise<string> | undefined

function write(level: Level, message: string, extra: unknown[]): void {
  const line = format(level, message, extra)
  if (level === 'error') {
    process.stderr.write(line)
  } else if (!app.isPackaged) {
    process.stdout.write(line)
  }
  logDirReady ??= (async () => {
    const dir = join(app.getPath('userData'), 'logs')
    await mkdir(dir, { recursive: true })
    return dir
  })()
  void logDirReady
    .then((dir) => appendFile(join(dir, `${new Date().toISOString().slice(0, 10)}.log`), line))
    .catch(() => undefined)
}

/** Minimal file + console logger for the main process (no remote reporting). */
export const log = {
  debug: (message: string, ...extra: unknown[]) => write('debug', message, extra),
  info: (message: string, ...extra: unknown[]) => write('info', message, extra),
  warn: (message: string, ...extra: unknown[]) => write('warn', message, extra),
  error: (message: string, ...extra: unknown[]) => write('error', message, extra),
}
