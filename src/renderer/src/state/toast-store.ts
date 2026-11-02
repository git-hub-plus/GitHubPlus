import { create } from 'zustand'
import { GhpError } from '@shared/errors'
import type { TranslationKey } from '@shared/i18n'

export interface Toast {
  id: string
  kind: 'success' | 'error'
  message: TranslationKey
  detail?: string
}
export const useToastStore = create<{ toasts: Toast[] }>(() => ({ toasts: [] }))
export function dismissToast(id: string): void {
  useToastStore.setState((s) => ({ toasts: s.toasts.filter((item) => item.id !== id) }))
}
export function showToast(
  input: unknown = 'repoActions.done',
  kind: Toast['kind'] = 'success'
): void {
  const error = input instanceof Error
  const id = crypto.randomUUID()
  const message: TranslationKey = error
    ? input instanceof GhpError
      ? errorKeys[input.kind]
      : 'repoActions.errors.unknown'
    : (input as TranslationKey)
  useToastStore.setState((s) => ({
    toasts: [
      ...s.toasts,
      {
        id,
        kind: error ? 'error' : kind,
        message,
        detail: error
          ? [input.message, input instanceof GhpError ? input.detail : undefined]
              .filter(Boolean)
              .join('\n')
          : undefined,
      },
    ],
  }))
  if (!error && kind === 'success') setTimeout(() => dismissToast(id), 3500)
}
const errorKeys: Record<GhpError['kind'], TranslationKey> = {
  'not-a-repository': 'repoActions.errors.notRepository',
  'authentication-failed': 'repoActions.errors.authentication',
  'push-rejected': 'repoActions.errors.rejected',
  'push-needs-pull': 'repoActions.errors.needsPull',
  'merge-conflicts': 'repoActions.errors.conflicts',
  'local-changes-overwritten': 'repoActions.errors.localChanges',
  'branch-exists': 'repoActions.errors.branchExists',
  'no-upstream': 'repoActions.errors.upstream',
  network: 'repoActions.errors.network',
  'hub-history-protected': 'repoActions.errors.protected',
  'invalid-argument': 'repoActions.errors.invalid',
  'not-found': 'repoActions.errors.notFound',
  internal: 'repoActions.errors.unknown',
  unknown: 'repoActions.errors.unknown',
}
