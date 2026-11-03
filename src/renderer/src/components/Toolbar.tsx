import { useCallback, useEffect, useState } from 'react'
import { useSelectedRepository } from '../state/app-store'
import { useRepoStore } from '../state/repo-store'
import { synchronize, useSyncStore, dismissOperation } from '../state/sync-store'
import { useT } from '../i18n'
import { BranchPopover } from './toolbar/BranchPopover'
import { relativeTime } from '../lib/relative-time'
import noticeStyles from './toolbar/Actions.module.css'
import styles from './Toolbar.module.css'

export function Toolbar() {
  const t = useT()
  const repository = useSelectedRepository()
  const status = useRepoStore((s) => (s.repoId === repository?.id ? s.status : undefined))
  const { active, lastFetch, needsPull, notices } = useSyncStore()
  const [branchRepo, setBranchRepo] = useState<string>()
  const closeBranches = useCallback(() => setBranchRepo(undefined), [])
  const command = !status?.upstream
    ? 'publish'
    : status.behind > 0
      ? 'pull'
      : status.ahead > 0
        ? 'push'
        : 'fetch'
  const [now, setNow] = useState(Date.now)
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 10000)
    return () => clearInterval(timer)
  }, [])
  const last = repository ? lastFetch[repository.id] : undefined
  return (
    <>
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
            ? Math.max(0, now - last) < 10000
              ? t('repoActions.fetchedNow')
              : t('repoActions.lastFetch', { time: relativeTime(last, now) })
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
      <aside
        className={noticeStyles.operationNotices}
        aria-label={t('repoActions.notifications')}
        aria-live="polite"
      >
        {notices.map((notice) => (
          <div key={notice.id} className={noticeStyles.toast} role="status">
            <p>{t(notice.message, notice.params)}</p>
            <button onClick={() => dismissOperation(notice.id)}>{t('common.close')}</button>
          </div>
        ))}
      </aside>
    </>
  )
}
