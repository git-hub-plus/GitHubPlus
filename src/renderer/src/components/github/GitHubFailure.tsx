import { GhpError } from '@shared/errors'
import { useT } from '../../i18n'

export function GitHubFailure({ error }: { error?: unknown }) {
  const t = useT()
  if (error === undefined) return null
  const kind = error instanceof GhpError ? error.kind : 'unknown'
  return (
    <div role="alert">
      {t(
        kind === 'authentication-failed'
          ? 'repoActions.errors.authentication'
          : kind === 'network'
            ? 'repoActions.errors.network'
            : kind === 'invalid-argument'
              ? 'repoActions.errors.invalid'
              : 'github.failed'
      )}
      <details>
        <summary>{t('common.details')}</summary>
        <pre>
          {error instanceof Error ? error.message : String(error)}
          {error instanceof GhpError && error.detail ? `\n${error.detail}` : ''}
        </pre>
      </details>
    </div>
  )
}
