import { useCallback, useEffect, useState } from 'react'
import { useHubStore } from '../state/hub-store'
import { invoke, subscribe } from '../ipc'
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
  const hub = useHubStore()
  useEffect(() => {
    let cancelled = false
    let received = false
    const off = subscribe('hub:statusChanged', (status) => {
      received = true
      useHubStore.setState({ status })
    })
    void Promise.resolve()
      .then(() => invoke('hub:status'))
      .then((status) => {
        if (!cancelled && !received && status) useHubStore.setState({ status })
      })
      .catch(() => {})
    return () => {
      cancelled = true
      off()
    }
  }, [])
  const [hubRemote, setHubRemote] = useState<{ repoId: string; url?: string }>()
  useEffect(() => {
    if (!repository || repository.group !== 'hub') return
    let cancelled = false
    void invoke('git:remotes', repository.id)
      .then((remotes) => {
        if (!cancelled)
          setHubRemote({
            repoId: repository.id,
            url: remotes?.find((remote) => remote.name === 'origin')?.url ?? remotes?.[0]?.url,
          })
      })
      .catch(() => {})
    return () => {
      cancelled = true
    }
  }, [repository])
  const remoteUrl =
    (hubRemote?.repoId === repository?.id ? hubRemote?.url : undefined) ?? repository?.remoteUrl
  const connectedHub = hub.hubs.find((item) => {
    try {
      const remote = new URL(remoteUrl ?? '')
      const base = new URL(item.url)
      return (
        remote.origin === base.origin &&
        remote.pathname.startsWith(base.pathname.replace(/\/$/, '') + '/')
      )
    } catch {
      return false
    }
  })
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
        {hub.status?.running && (
          <button className={styles.hubStatus} onClick={() => hub.open('host')}>
            {t('lfs.hubStatus.running')}
          </button>
        )}
        {(repository?.group === 'hub' || connectedHub) && (
          <span className={styles.label} role="status">
            {t(connectedHub?.online ? 'lfs.hubStatus.connected' : 'lfs.hubStatus.offline')}
          </span>
        )}
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
