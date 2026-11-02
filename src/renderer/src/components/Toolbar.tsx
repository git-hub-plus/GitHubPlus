import { useCallback, useState } from 'react'
import { useSelectedRepository } from '../state/app-store'
import { useRepoStore } from '../state/repo-store'
import { synchronize, useSyncStore } from '../state/sync-store'
import { useT } from '../i18n'
import { BranchPopover } from './toolbar/BranchPopover'
import styles from './Toolbar.module.css'

export function Toolbar() {
  const t = useT()
  const repository = useSelectedRepository()
  const status = useRepoStore((s) => (s.repoId === repository?.id ? s.status : undefined))
  const { active, lastFetch, needsPull } = useSyncStore()
  const [branchRepo, setBranchRepo] = useState<string>()
  const closeBranches = useCallback(() => setBranchRepo(undefined), [])
  const command = !status?.upstream
    ? 'publish'
    : status.behind > 0
      ? 'pull'
      : status.ahead > 0
        ? 'push'
        : 'fetch'
  const last = repository ? lastFetch[repository.id] : undefined
  return (
    <header className={styles.toolbar}>
      <div className={styles.anchor}>
        <button
          className={styles.branch}
          disabled={!repository || !status || !!active}
          aria-expanded={branchRepo === repository?.id && !!branchRepo}
          onClick={() => setBranchRepo(branchRepo ? undefined : repository?.id)}
        >
          <span className={styles.label}>{t('toolbar.branch')}</span>{' '}
          <span>
            {status?.currentBranch ?? status?.headSha?.slice(0, 7) ?? t('toolbar.noBranch')}
          </span>
        </button>
        {repository && branchRepo === repository.id && (
          <BranchPopover key={repository.id} repoId={repository.id} onClose={closeBranches} />
        )}
      </div>
      <button
        className={styles.action}
        disabled={
          !repository || !status || !!active || (!status.currentBranch && command === 'publish')
        }
        onClick={() => void synchronize(command)}
      >
        {t(`toolbar.${command}`, {
          count: command === 'pull' ? (status?.behind ?? 0) : (status?.ahead ?? 0),
        })}
      </button>
      <span className={styles.label}>
        {last
          ? t('repoActions.lastFetch', { time: new Date(last).toLocaleTimeString() })
          : t('repoActions.neverFetched')}
      </span>
      {active && active.repoId === repository?.id && (
        <progress
          className={styles.progress}
          max={1}
          value={active.progress?.value}
          aria-label={t('repoActions.progress')}
        />
      )}
      {repository && needsPull === repository.id && (
        <span role="alert">
          {t('repoActions.errors.needsPull')}{' '}
          <button disabled={!!active} onClick={() => void synchronize('pull')}>
            {t('repoActions.pull')}
          </button>
        </span>
      )}
      <div className={styles.spacer} />
    </header>
  )
}
