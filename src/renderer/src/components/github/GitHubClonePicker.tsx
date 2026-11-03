import { useEffect, useId, useRef, useState } from 'react'
import { useT } from '../../i18n'
import { useGitHubStore } from '../../state/github-store'
import { GitHubSignIn } from './GitHubAccountSection'
import { GitHubFailure } from './GitHubFailure'
import styles from './GitHub.module.css'

export function GitHubClonePicker({ url, onSelect }: { url: string; onSelect(url: string): void }) {
  const t = useT()
  const account = useGitHubStore((state) => state.account)
  const repositories = useGitHubStore((state) => state.repositories)
  const [search, setSearch] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<unknown>()
  const [attempt, setAttempt] = useState(0)
  const list = useRef<HTMLDivElement>(null)
  const searchId = useId()
  const login = account?.login
  useEffect(() => {
    void useGitHubStore.getState().refreshAccount().catch(setError)
  }, [])
  useEffect(() => {
    if (!login) return
    let alive = true
    void Promise.resolve()
      .then(async () => {
        if (!alive) return
        setLoading(true)
        setError(undefined)
        await useGitHubStore.getState().loadRepositories()
      })
      .catch((error) => {
        if (alive) setError(error)
      })
      .finally(() => {
        if (alive) setLoading(false)
      })
    return () => {
      alive = false
    }
  }, [login, attempt])
  const filtered = repositories.filter((repo) =>
    repo.fullName.toLowerCase().includes(search.toLowerCase())
  )
  return (
    <>
      {!account ? (
        <GitHubSignIn />
      ) : (
        <>
          <label htmlFor={searchId}>{t('github.search')}</label>
          <input id={searchId} value={search} onChange={(event) => setSearch(event.target.value)} />
          {loading ? (
            <p role="status">{t('common.loading')}</p>
          ) : (
            <div
              ref={list}
              className={styles.list}
              role="listbox"
              aria-label={t('github.repositories')}
              onKeyDown={(event) => {
                if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return
                event.preventDefault()
                const items = Array.from(
                  list.current?.querySelectorAll<HTMLButtonElement>('[role="option"]') ?? []
                )
                const current = items.indexOf(document.activeElement as HTMLButtonElement)
                items[
                  (current + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length
                ]?.focus()
              }}
            >
              {filtered.map((repo) => (
                <button
                  key={repo.fullName}
                  type="button"
                  role="option"
                  aria-selected={repo.cloneUrl === url}
                  className={styles.row}
                  onClick={() => onSelect(repo.cloneUrl)}
                >
                  <span>{repo.fullName}</span>
                  <span>{repo.private ? t('github.private') : ''}</span>
                </button>
              ))}
            </div>
          )}
          {!loading && filtered.length === 0 && <p>{t('github.empty')}</p>}
        </>
      )}
      <GitHubFailure error={error} />
      {error !== undefined && (
        <button type="button" onClick={() => setAttempt((value) => value + 1)}>
          {t('common.retry')}
        </button>
      )}
    </>
  )
}
