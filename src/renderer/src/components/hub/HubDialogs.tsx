import { useEffect, useMemo, useRef, useState } from 'react'
import type { DiscoveredHub, HubRepository, HubSettings } from '@shared/ipc/hub'
import type { Commit, CommittedFile, GitProgress } from '@shared/models/git'
import type { FileDiff } from '@shared/models/diff'
import { GhpError } from '@shared/errors'
import { useT } from '../../i18n'
import { invoke, subscribe } from '../../ipc'
import { useHubStore, connectHubStore } from '../../state/hub-store'
import { useAppStore } from '../../state/app-store'
import { calculateCommitGraph } from '../../lib/commit-graph'
import { Dialog } from '../dialogs/Dialog'
import { VirtualList } from '../common/VirtualList'
import { DiffView } from '../diff/DiffView'
import { ConfirmDialog } from '../common/ConfirmDialog'
import styles from './HubDialogs.module.css'

function useTask() {
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<Error>()
  const lock = useRef(false)
  const run = async (task: () => Promise<void>) => {
    if (lock.current) return
    lock.current = true
    setBusy(true)
    setError(undefined)
    try {
      await task()
    } catch (error) {
      setError(error instanceof Error ? error : new Error(String(error)))
    } finally {
      lock.current = false
      setBusy(false)
    }
  }
  return { busy, error, run }
}

function Failure({ error }: { error?: Error }) {
  const t = useT()
  if (!error) return null
  const kind = error instanceof GhpError ? error.kind : 'unknown'
  return (
    <div role="alert" className={styles.error}>
      {t(
        kind === 'network'
          ? 'hub.networkError'
          : kind === 'invalid-argument'
            ? 'hub.invalidError'
            : kind === 'not-found'
              ? 'hub.notFoundError'
              : 'hub.failed'
      )}
      <details>
        <summary>{t('common.details')}</summary>
        <pre>
          {error.message}
          {error instanceof GhpError && error.detail ? `\n${error.detail}` : ''}
        </pre>
      </details>
    </div>
  )
}

function Progress({ opId }: { opId?: string }) {
  const t = useT()
  const [event, setEvent] = useState<{ opId: string; progress: GitProgress }>()
  useEffect(() => {
    return subscribe('git:progress', (event) => {
      if (event.opId === opId) setEvent(event)
    })
  }, [opId])
  return opId ? (
    <progress
      aria-label={t('hub.progress')}
      value={event?.opId === opId ? event.progress.value : 0}
      max={1}
    />
  ) : null
}

function HubList({
  hubs,
  selected,
  onSelect,
}: {
  hubs: ReadonlyArray<DiscoveredHub>
  selected: string
  onSelect: (url: string) => void
}) {
  const t = useT()
  return (
    <section className={styles.pane} aria-label={t('hub.hubs')}>
      <div className={styles.list} role="listbox" aria-label={t('hub.hubs')}>
        <VirtualList
          items={hubs}
          getKey={(hub) => hub.id}
          rowHeight={28}
          selectedIndex={hubs.findIndex((h) => h.url === selected)}
          onSelect={(i) => onSelect(hubs[i].url)}
          renderRow={(hub) => (
            <button
              type="button"
              role="option"
              aria-selected={hub.url === selected}
              className={styles.row}
              title={hub.url}
              onClick={() => onSelect(hub.url)}
            >
              <span className={styles.truncate}>{hub.name}</span>
              <span className={styles.muted}>
                {t(hub.online ? 'hub.online' : 'hub.offline')} ·{' '}
                {t(hub.manual ? 'hub.manual' : 'hub.discovered')}
              </span>
            </button>
          )}
        />
      </div>
      {!hubs.length && <p className={styles.muted}>{t('hub.noHubs')}</p>}
    </section>
  )
}

export function HubDialogs() {
  const { dialog, repoId, close } = useHubStore()
  useEffect(connectHubStore, [])
  if (dialog === 'manual') return <ManualHubDialog onClose={close} />
  if (dialog === 'clone') return <CloneHubDialog onClose={close} />
  if (dialog === 'publish' && repoId) return <PublishHubDialog repoId={repoId} onClose={close} />
  if (dialog === 'host') return <LocalHubDialog onClose={close} />
  return null
}

export function ManualHubDialog({ onClose }: { onClose(): void }) {
  const t = useT()
  const hubs = useHubStore((s) => s.hubs)
  const [url, setUrl] = useState('')
  const task = useTask()
  return (
    <Dialog
      title={t('hub.addManual')}
      onClose={onClose}
      busy={task.busy}
      disabled={!url.trim()}
      submitLabel={t('hub.add')}
      onSubmit={() =>
        void task.run(async () => {
          const hub = await invoke('hub:addManual', url.trim())
          useHubStore.setState((s) => ({ hubs: [...s.hubs.filter((h) => h.id !== hub.id), hub] }))
          onClose()
        })
      }
    >
      <div className={styles.body}>
        <label className={styles.field}>
          {t('hub.url')}
          <input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder={t('hub.urlPlaceholder')}
          />
        </label>
        {hubs
          .filter((h) => h.manual)
          .map((hub) => (
            <div className={styles.actions} key={hub.id}>
              <span>
                {hub.name} — {hub.url}
              </span>
              <button
                type="button"
                disabled={task.busy}
                onClick={() =>
                  void task.run(async () => {
                    await invoke('hub:removeManual', hub.id)
                    useHubStore.setState((s) => ({ hubs: s.hubs.filter((h) => h.id !== hub.id) }))
                  })
                }
              >
                {t('hub.remove')}
              </button>
            </div>
          ))}
        <Failure error={task.error} />
      </div>
    </Dialog>
  )
}

export function CloneHubDialog({ onClose }: { onClose(): void }) {
  const t = useT()
  const hubs = useHubStore((s) => s.hubs)
  const [chosenUrl, setUrl] = useState('')
  const url = chosenUrl || hubs[0]?.url || ''
  const [repositories, setRepositories] = useState<ReadonlyArray<HubRepository>>([])
  const [selected, setSelected] = useState('')
  const [path, setPath] = useState('')
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [creating, setCreating] = useState(false)
  const [history, setHistory] = useState(false)
  const [pending, setLoading] = useState(true)
  const loading = Boolean(url) && pending
  const [loadError, setLoadError] = useState<Error>()
  const [revision, setRevision] = useState(0)
  const [opId, setOpId] = useState<string>()
  const task = useTask()
  const repository = repositories.find((repo) => repo.name === selected)
  useEffect(() => {
    let active = true
    if (!url) return
    void invoke('hub:listRemoteRepositories', url)
      .then((repos) => {
        if (active) {
          setRepositories(repos)
          setSelected(repos[0]?.name ?? '')
        }
      })
      .catch((error: Error) => {
        if (active) setLoadError(error)
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [url, revision])
  return (
    <Dialog
      title={t('hub.clone')}
      onClose={onClose}
      busy={task.busy}
      disabled={!repository || !path.trim() || loading}
      submitLabel={t('hub.cloneAction')}
      onSubmit={() =>
        void task.run(async () => {
          if (!repository) return
          const id = crypto.randomUUID()
          setOpId(id)
          try {
            const repo = await invoke('git:clone', {
              url: repository.url,
              path: path.trim(),
              opId: id,
            })
            useAppStore.setState((s) => ({
              repositories: [...s.repositories.filter((r) => r.id !== repo.id), repo],
            }))
            await useAppStore.getState().selectRepository(repo.id)
            onClose()
          } finally {
            setOpId(undefined)
          }
        })
      }
    >
      <div className={styles.body}>
        <div className={styles.columns}>
          <HubList
            hubs={hubs}
            selected={url}
            onSelect={(value) => {
              if (!task.busy && value !== url) {
                setUrl(value)
                setRepositories([])
                setSelected('')
                setHistory(false)
                setLoadError(undefined)
                setLoading(true)
              }
            }}
          />
          <section className={styles.pane} aria-label={t('hub.repositories')}>
            {loading && <span role="status">{t('common.loading')}</span>}
            <div className={styles.list} role="listbox" aria-label={t('hub.repositories')}>
              <VirtualList
                items={repositories}
                getKey={(repo) => repo.name}
                rowHeight={28}
                selectedIndex={repositories.findIndex((repo) => repo.name === selected)}
                onSelect={(i) => {
                  setSelected(repositories[i].name)
                  setHistory(false)
                }}
                renderRow={(repo) => (
                  <button
                    type="button"
                    role="option"
                    aria-selected={repo.name === selected}
                    className={styles.row}
                    onClick={() => {
                      setSelected(repo.name)
                      setHistory(false)
                    }}
                  >
                    <strong className={styles.truncate}>{repo.name}</strong>
                    <span className={`${styles.muted} ${styles.truncate}`}>{repo.description}</span>
                    <time className={styles.muted}>
                      {repo.lastPushAt
                        ? new Date(repo.lastPushAt).toLocaleString()
                        : t('hub.noPush')}
                    </time>
                  </button>
                )}
              />
            </div>
            {!loading && !repositories.length && (
              <p className={styles.muted}>{t('hub.noRepositories')}</p>
            )}
            <div className={styles.actions}>
              <button
                type="button"
                disabled={!repository || task.busy}
                onClick={() => setHistory(!history)}
              >
                {t('hub.history')}
              </button>
              <button
                type="button"
                disabled={!url || task.busy}
                onClick={() => setCreating(!creating)}
              >
                {t('hub.create')}
              </button>
              <button
                type="button"
                disabled={task.busy}
                onClick={() => {
                  setLoadError(undefined)
                  setLoading(true)
                  setRevision((r) => r + 1)
                }}
              >
                {t('common.retry')}
              </button>
            </div>
          </section>
        </div>
        {creating && (
          <fieldset disabled={task.busy}>
            <legend>{t('hub.create')}</legend>
            <label className={styles.field}>
              {t('hub.name')}
              <input value={name} onChange={(e) => setName(e.target.value)} />
            </label>
            <label className={styles.field}>
              {t('hub.description')}
              <input value={description} onChange={(e) => setDescription(e.target.value)} />
            </label>
            <button
              type="button"
              disabled={!name.trim()}
              onClick={() =>
                void task.run(async () => {
                  const repo = await invoke(
                    'hub:createRemoteRepository',
                    url,
                    name.trim(),
                    description.trim() || undefined
                  )
                  setRepositories((items) => [...items, repo])
                  setSelected(repo.name)
                  setCreating(false)
                  setName('')
                  setDescription('')
                })
              }
            >
              {t('hub.create')}
            </button>
          </fieldset>
        )}
        <div className={styles.actions}>
          <label className={styles.field}>
            {t('hub.destination')}
            <input value={path} disabled={task.busy} onChange={(e) => setPath(e.target.value)} />
          </label>
          <button
            type="button"
            disabled={task.busy}
            onClick={() =>
              void task.run(async () => {
                const folder = await invoke('dialog:pickDirectory')
                if (folder) setPath(`${folder.replace(/[\\/]$/, '')}/${repository?.name ?? ''}`)
              })
            }
          >
            {t('hub.chooseFolder')}
          </button>
        </div>
        <Progress opId={opId} />
        <Failure error={task.error ?? loadError} />
        {history && repository && (
          <RemoteHistory key={`${url}/${repository.name}`} url={url} repository={repository.name} />
        )}
      </div>
    </Dialog>
  )
}

export function PublishHubDialog({ repoId, onClose }: { repoId: string; onClose(): void }) {
  const t = useT()
  const hubs = useHubStore((s) => s.hubs)
  const repo = useAppStore((s) => s.repositories.find((r) => r.id === repoId))
  const [chosenUrl, setUrl] = useState('')
  const url = chosenUrl || hubs[0]?.url || ''
  const [name, setName] = useState(repo?.name ?? '')
  const [description, setDescription] = useState('')
  const [opId, setOpId] = useState<string>()
  const task = useTask()
  return (
    <Dialog
      title={t('hub.publish')}
      busy={task.busy}
      disabled={!url || !name.trim()}
      onClose={onClose}
      submitLabel={t('hub.publishAction')}
      onSubmit={() =>
        void task.run(async () => {
          const id = crypto.randomUUID()
          setOpId(id)
          try {
            await invoke('hub:publish', repoId, {
              hubUrl: url,
              name: name.trim(),
              description: description.trim() || undefined,
              opId: id,
            })
            onClose()
          } finally {
            setOpId(undefined)
          }
        })
      }
    >
      <div className={styles.body}>
        <fieldset disabled={task.busy}>
          <legend>{t('hub.hubs')}</legend>
          <HubList hubs={hubs} selected={url} onSelect={setUrl} />
        </fieldset>
        <label className={styles.field}>
          {t('hub.name')}
          <input disabled={task.busy} value={name} onChange={(e) => setName(e.target.value)} />
        </label>
        <label className={styles.field}>
          {t('hub.description')}
          <input
            disabled={task.busy}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
        </label>
        <Progress opId={opId} />
        <Failure error={task.error} />
      </div>
    </Dialog>
  )
}

export function RemoteHistory({ url, repository }: { url: string; repository: string }) {
  return <RemoteHistoryContent key={`${url}/${repository}`} url={url} repository={repository} />
}

function RemoteHistoryContent({ url, repository }: { url: string; repository: string }) {
  const t = useT()
  const [commits, setCommits] = useState<ReadonlyArray<Commit>>([])
  const [sha, setSha] = useState('')
  const [files, setFiles] = useState<ReadonlyArray<CommittedFile>>([])
  const [path, setPath] = useState('')
  const [diff, setDiff] = useState<FileDiff>()
  const [error, setError] = useState<Error>()
  const [loading, setLoading] = useState(true)
  const [more, setMore] = useState(true)
  const [revision, setRevision] = useState(0)
  const task = useTask()
  const selectSha = (value: string) => {
    setSha(value)
    setFiles([])
    setPath('')
    setDiff(undefined)
    setError(undefined)
  }
  const selectPath = (value: string) => {
    setPath(value)
    setDiff(undefined)
    setError(undefined)
  }
  const graph = useMemo(() => calculateCommitGraph(commits).rows, [commits])
  const graphWidth = graph.reduce((width, row) => Math.max(width, row.width), 1)
  useEffect(() => {
    let active = true
    void invoke('hub:remoteLog', url, repository, { limit: 100 })
      .then((items) => {
        if (active) {
          setCommits(items)
          setSha(items[0]?.sha ?? '')
          setMore(items.length === 100)
        }
      })
      .catch((error: Error) => {
        if (active) setError(error)
      })
      .finally(() => {
        if (active) setLoading(false)
      })
    return () => {
      active = false
    }
  }, [url, repository, revision])
  useEffect(() => {
    let active = true
    if (!sha) return
    void invoke('hub:remoteCommitFiles', url, repository, sha)
      .then((items) => {
        if (active) {
          setFiles(items)
          setPath(items[0]?.path ?? '')
        }
      })
      .catch((error: Error) => {
        if (active) setError(error)
      })
    return () => {
      active = false
    }
  }, [url, repository, sha])
  useEffect(() => {
    let active = true
    if (!sha || !path) return
    void invoke('hub:remoteCommitDiff', url, repository, sha, path)
      .then((value) => {
        if (active) setDiff(value)
      })
      .catch((error: Error) => {
        if (active) setError(error)
      })
    return () => {
      active = false
    }
  }, [url, repository, sha, path])
  return (
    <section className={styles.pane} aria-label={t('hub.history')}>
      <h3>
        {t('hub.history')} — {repository}
      </h3>
      {loading && <span role="status">{t('common.loading')}</span>}
      {!loading && !commits.length && <p>{t('hub.noCommits')}</p>}
      <div className={styles.columns}>
        <div className={styles.list} role="listbox" aria-label={t('hub.commits')}>
          <VirtualList
            items={commits}
            rowHeight={28}
            getKey={(commit) => commit.sha}
            selectedIndex={commits.findIndex((c) => c.sha === sha)}
            onSelect={(i) => selectSha(commits[i].sha)}
            renderRow={(commit, i) => {
              const row = graph[i]
              const x = (lane: number) => lane * 12 + 8
              return (
                <button
                  type="button"
                  role="option"
                  aria-selected={sha === commit.sha}
                  className={styles.row}
                  onClick={() => selectSha(commit.sha)}
                >
                  <svg
                    className={styles.graph}
                    aria-hidden="true"
                    height={28}
                    width={graphWidth * 12 + 12}
                  >
                    {row.edges.map((edge, j) => (
                      <path
                        key={j}
                        d={`M${x(edge.fromLane)},${edge.type === 'incoming' || edge.type === 'continue' ? 0 : 14} L${x(edge.toLane)},${edge.type === 'incoming' ? 14 : 28}`}
                        stroke="currentColor"
                        fill="none"
                      />
                    ))}
                    <circle cx={x(row.lane)} cy={14} r={3} fill="currentColor" />
                  </svg>
                  <span className={styles.truncate}>
                    {commit.shortSha} {commit.summary}
                  </span>
                </button>
              )
            }}
          />
        </div>
        <div className={styles.list} role="listbox" aria-label={t('hub.files')}>
          <VirtualList
            items={files}
            rowHeight={28}
            getKey={(file) => file.path}
            selectedIndex={files.findIndex((f) => f.path === path)}
            onSelect={(i) => selectPath(files[i].path)}
            renderRow={(file) => (
              <button
                type="button"
                role="option"
                aria-selected={path === file.path}
                className={styles.row}
                onClick={() => selectPath(file.path)}
              >
                {file.path}
              </button>
            )}
          />
        </div>
      </div>
      {more && commits.length > 0 && (
        <button
          type="button"
          disabled={task.busy}
          onClick={() =>
            void task.run(async () => {
              const items = await invoke('hub:remoteLog', url, repository, {
                limit: 100,
                skip: commits.length,
              })
              setCommits((current) => [...current, ...items])
              setMore(items.length === 100)
            })
          }
        >
          {t('hub.loadMore')}
        </button>
      )}
      <button
        type="button"
        disabled={loading}
        onClick={() => {
          selectSha('')
          setCommits([])
          setLoading(true)
          setRevision((r) => r + 1)
        }}
      >
        {t('common.retry')}
      </button>
      <Failure error={error ?? task.error} />
      {diff && (
        <div className={styles.diff}>
          <DiffView diff={diff} path={path} />
        </div>
      )}
    </section>
  )
}

export function LocalHubDialog({ onClose }: { onClose(): void }) {
  const t = useT()
  const status = useHubStore((s) => s.status)
  const pushes = useHubStore((s) => s.pushes)
  const [settings, setSettings] = useState<HubSettings>()
  const [repos, setRepos] = useState<ReadonlyArray<HubRepository>>([])
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [deleting, setDeleting] = useState<string>()
  const [copied, setCopied] = useState('')
  const [revision, setRevision] = useState(0)
  const [loadError, setLoadError] = useState<Error>()
  const [completedRevision, setCompletedRevision] = useState(-1)
  const loading = completedRevision !== revision
  const task = useTask()
  useEffect(() => {
    let active = true
    let statusEvent = false
    const received: (typeof pushes)[number][] = []
    const offStatus = subscribe('hub:statusChanged', () => {
      statusEvent = true
    })
    const offPush = subscribe('hub:pushReceived', (push) => received.push(push))
    void Promise.all([
      invoke('hub:getSettings'),
      invoke('hub:status'),
      invoke('hub:listLocalRepositories'),
      invoke('hub:pushLog', { limit: 100 }),
    ])
      .then(([settings, status, repos, pushes]) => {
        if (!active) return
        setSettings(settings)
        setRepos(repos)
        useHubStore.setState({
          ...(statusEvent ? {} : { status }),
          pushes: [...received.reverse(), ...pushes].slice(0, 100),
        })
      })
      .catch((error: Error) => {
        if (active) setLoadError(error)
      })
      .finally(() => {
        if (active) setCompletedRevision(revision)
      })
    return () => {
      active = false
      offStatus()
      offPush()
    }
  }, [revision])
  const update = (patch: Partial<HubSettings>) => {
    if (settings) setSettings({ ...settings, ...patch })
  }
  const save = (enabled?: boolean) =>
    void task.run(async () => {
      if (!settings) return
      setSettings(
        await invoke('hub:updateSettings', {
          ...settings,
          enabled: enabled ?? status?.running ?? settings.enabled,
        })
      )
      useHubStore.setState({ status: await invoke('hub:status') })
    })
  return (
    <Dialog
      title={t('hub.title')}
      onClose={onClose}
      busy={task.busy}
      disabled={!settings || loading}
      submitLabel={t('hub.save')}
      onSubmit={() => save()}
    >
      <div className={styles.body}>
        {loading && <span role="status">{t('common.loading')}</span>}
        <Failure error={task.error ?? loadError} />
        {loadError && (
          <button
            type="button"
            onClick={() => {
              setLoadError(undefined)
              setRevision((r) => r + 1)
            }}
          >
            {t('common.retry')}
          </button>
        )}
        {settings && (
          <>
            <div className={styles.actions}>
              <strong>{t(status?.running ? 'hub.running' : 'hub.stopped')}</strong>
              <button type="button" disabled={task.busy} onClick={() => save(!status?.running)}>
                {t(status?.running ? 'hub.stop' : 'hub.start')}
              </button>
            </div>
            {status?.error && (
              <p role="alert" className={styles.error}>
                {status.error}
              </p>
            )}
            <fieldset disabled={task.busy || loading}>
              <legend>{t('hub.settings')}</legend>
              <div className={styles.fields}>
                <label className={styles.field}>
                  {t('hub.hubName')}
                  <input value={settings.name} onChange={(e) => update({ name: e.target.value })} />
                </label>
                <label className={styles.field}>
                  {t('hub.port')}
                  <input
                    type="number"
                    min={1}
                    max={65535}
                    required
                    value={settings.port}
                    onChange={(e) => update({ port: Number(e.target.value) })}
                  />
                </label>
              </div>
              <label className={styles.field}>
                {t('hub.rootDirectory')}
                <input
                  required
                  value={settings.rootDirectory}
                  onChange={(e) => update({ rootDirectory: e.target.value })}
                />
              </label>
              <button
                type="button"
                onClick={() =>
                  void task.run(async () => {
                    const folder = await invoke('dialog:pickDirectory')
                    if (folder) update({ rootDirectory: folder })
                  })
                }
              >
                {t('hub.chooseFolder')}
              </button>
              <label className={styles.check}>
                <input
                  type="checkbox"
                  checked={settings.keepRunningInTray}
                  onChange={(e) => update({ keepRunningInTray: e.target.checked })}
                />
                {t('hub.tray')}
              </label>
              <label className={styles.check}>
                <input
                  type="checkbox"
                  checked={settings.startWithWindows}
                  onChange={(e) => update({ startWithWindows: e.target.checked })}
                />
                {t('hub.startWithWindows')}
              </label>
            </fieldset>
            {!status?.running && <p className={styles.muted}>{t('hub.firewall')}</p>}
            <section className={styles.pane} aria-label={t('hub.addresses')}>
              <h3>{t('hub.addresses')}</h3>
              {status?.addresses.map((address) => (
                <div className={styles.actions} key={address}>
                  <code>{address}</code>
                  <button
                    type="button"
                    onClick={() =>
                      void task.run(async () => {
                        await navigator.clipboard.writeText(address)
                        setCopied(address)
                      })
                    }
                  >
                    {t(copied === address ? 'hub.copied' : 'hub.copy')}
                  </button>
                </div>
              ))}
              {!status?.addresses.length && <p className={styles.muted}>{t('hub.noAddresses')}</p>}
            </section>
            <h3>{t('hub.repositories')}</h3>
            <div className={styles.list}>
              <VirtualList
                items={repos}
                rowHeight={28}
                getKey={(repo) => repo.name}
                renderRow={(repo) => (
                  <div className={styles.row}>
                    <span className={styles.truncate}>{repo.name}</span>
                    <span className={styles.muted}>{repo.description}</span>
                    <button
                      type="button"
                      disabled={task.busy}
                      onClick={() => setDeleting(repo.name)}
                    >
                      {t('hub.trash')}
                    </button>
                  </div>
                )}
              />
            </div>
            {!repos.length && <p className={styles.muted}>{t('hub.noRepositories')}</p>}
            {deleting && (
              // ConfirmDialog's shared buttons omit type; prevent submission of this settings form.
              <div onClick={(event) => event.preventDefault()}>
                <ConfirmDialog
                  message={t('hub.confirmDelete', { name: deleting })}
                  onCancel={() => {
                    if (!task.busy) setDeleting(undefined)
                  }}
                  onConfirm={() =>
                    void task.run(async () => {
                      await invoke('hub:deleteLocalRepository', deleting)
                      setRepos((repos) => repos.filter((repo) => repo.name !== deleting))
                      setDeleting(undefined)
                    })
                  }
                />
              </div>
            )}
            <fieldset disabled={task.busy}>
              <legend>{t('hub.create')}</legend>
              <label className={styles.field}>
                {t('hub.name')}
                <input value={name} onChange={(e) => setName(e.target.value)} />
              </label>
              <label className={styles.field}>
                {t('hub.description')}
                <input value={description} onChange={(e) => setDescription(e.target.value)} />
              </label>
              <button
                type="button"
                disabled={!name.trim()}
                onClick={() =>
                  void task.run(async () => {
                    const repo = await invoke(
                      'hub:createLocalRepository',
                      name.trim(),
                      description.trim() || undefined
                    )
                    setRepos((repos) => [...repos, repo])
                    setName('')
                    setDescription('')
                  })
                }
              >
                {t('hub.create')}
              </button>
            </fieldset>
            <h3>{t('hub.pushes')}</h3>
            <ol className={styles.pushes}>
              {pushes.map((push, i) => (
                <li key={`${push.at}-${push.newSha}-${i}`}>
                  <time>{new Date(push.at).toLocaleString()}</time> — {push.repository} — {push.ref}{' '}
                  — {push.clientHost ?? push.clientAddress}
                </li>
              ))}
            </ol>
            {!pushes.length && <p className={styles.muted}>{t('hub.noPushes')}</p>}
          </>
        )}
      </div>
    </Dialog>
  )
}
