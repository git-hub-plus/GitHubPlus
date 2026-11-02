// Ported from GitHub Desktop (MIT): app/src/lib/progress/from-process.ts
import { StringDecoder } from 'node:string_decoder'
import type { GitProgress } from '@shared/models/git'
import { git } from '../core'
import { CloneProgressParser } from './clone'
import { FetchProgressParser } from './fetch'
import { PullProgressParser } from './pull'
import { PushProgressParser } from './push'
import { CheckoutProgressParser } from './checkout'

export type ProgressCallback = (progress: GitProgress) => void
type Kind = Exclude<GitProgress['kind'], 'generic'>
const parsers = {
  clone: CloneProgressParser,
  fetch: FetchProgressParser,
  pull: PullProgressParser,
  push: PushProgressParser,
  checkout: CheckoutProgressParser,
}

/** Decode arbitrary stderr chunks, including CR updates and a final unterminated line. */
export function progressStream(
  kind: Kind,
  title: string,
  callback: ProgressCallback
): { write: (chunk: Buffer) => void; end: () => void } {
  const parser = new parsers[kind]()
  const decoder = new StringDecoder('utf8')
  let pending = ''
  let value = 0
  const line = (text: string): void => {
    const result = parser.parse(text)
    if (result.kind !== 'progress') return
    value = Math.max(value, Math.min(1, Math.max(0, result.percent)))
    callback({ kind, title, value, description: result.details.text })
  }
  const consume = (text: string): void => {
    pending += text
    const lines = pending.split(/[\r\n]/)
    pending = lines.pop() ?? ''
    lines.filter(Boolean).forEach(line)
  }
  return {
    write: (chunk) => consume(decoder.write(chunk)),
    end: () => {
      consume(decoder.end())
      if (pending) line(pending)
      pending = ''
    },
  }
}

export async function runWithProgress(
  args: string[],
  path: string,
  kind: Kind,
  title: string,
  callback?: ProgressCallback
): Promise<void> {
  callback?.({ kind, title, value: 0 })
  const stream = callback ? progressStream(kind, title, callback) : undefined
  try {
    await git(args, path, kind, {
      processCallback: stream
        ? (process) => {
            process.stderr?.on('data', stream.write)
          }
        : undefined,
    })
  } finally {
    stream?.end()
  }
  callback?.({ kind, title, value: 1 })
}
