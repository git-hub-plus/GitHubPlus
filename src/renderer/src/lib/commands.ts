import type { TranslationKey } from '@shared/i18n'

export interface Command {
  readonly id: string
  readonly label: TranslationKey
  readonly shortcut?: string
  readonly enabled?: () => boolean
  run(): void | Promise<void>
}
const commands = new Map<string, Command>()
const listeners = new Set<() => void>()
let snapshot: ReadonlyArray<Command> = []
function changed(): void {
  snapshot = [...commands.values()]
  listeners.forEach((listener) => listener())
}
/** Returns a disposer that cannot accidentally remove a replacement command. */
export function registerCommand(command: Command): () => void {
  commands.set(command.id, command)
  changed()
  return () => {
    if (commands.get(command.id) !== command) return
    commands.delete(command.id)
    changed()
  }
}
export const getCommands = (): ReadonlyArray<Command> => snapshot
export function subscribeCommands(listener: () => void): () => void {
  listeners.add(listener)
  return () => {
    listeners.delete(listener)
  }
}

/** Subsequence matching rewards exact/prefix matches, word starts and adjacency. */
export function fuzzyScore(text: string, query: string): number | undefined {
  const haystack = text.normalize('NFKC').toLocaleLowerCase()
  const needle = query.normalize('NFKC').toLocaleLowerCase().trim()
  if (!needle) return 0
  if (haystack === needle) return 10000
  const direct = haystack.indexOf(needle)
  if (direct >= 0) return 5000 - direct * 5 - (haystack.length - needle.length)
  let previous = -1
  let score = 0
  for (const char of needle) {
    if (char === ' ') continue
    const index = haystack.indexOf(char, previous + 1)
    if (index < 0) return undefined
    score += 10 + (index === previous + 1 ? 20 : 0)
    if (index === 0 || /[\s/:_-]/.test(haystack[index - 1])) score += 15
    score -= index - previous - 1
    previous = index
  }
  return score - haystack.length / 100
}
