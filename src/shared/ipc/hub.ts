import type { FileDiff } from '../models/diff'
import type { Commit, CommittedFile } from '../models/git'

/** Host-side hub settings (stored by the main process). */
export interface HubSettings {
  readonly enabled: boolean
  readonly port: number
  /** Folder holding the hub's bare repositories (`<name>.git`). */
  readonly rootDirectory: string
  /** Name announced on the LAN, e.g. "사무실 허브". */
  readonly name: string
  readonly startWithWindows: boolean
  /** Keep serving from the tray when the window closes. */
  readonly keepRunningInTray: boolean
  /** Optional folder for periodic `git bundle` backups. */
  readonly backupDirectory?: string
}

export interface HubServerStatus {
  readonly running: boolean
  readonly port: number
  /** Base URLs clients can use, e.g. `http://192.168.0.10:8765`. */
  readonly addresses: ReadonlyArray<string>
  readonly repositoryCount: number
  readonly error?: string
}

export interface HubRepository {
  readonly name: string
  readonly description?: string
  readonly defaultBranch?: string
  readonly lastPushAt?: number
  /** Git clone URL, e.g. `http://192.168.0.10:8765/team-api.git`. */
  readonly url: string
}

export interface HubPushRecord {
  readonly at: number
  readonly repository: string
  readonly ref: string
  readonly oldSha: string
  readonly newSha: string
  readonly clientAddress: string
  readonly clientHost?: string
}

/** A hub seen on the LAN (UDP announcement) or added by address. */
export interface DiscoveredHub {
  /** Stable id: the base URL. */
  readonly id: string
  readonly name: string
  /** Base URL, e.g. `http://192.168.0.10:8765`. */
  readonly url: string
  readonly lastSeen: number
  readonly manual: boolean
  readonly online: boolean
}

/**
 * Hub channels. Host side (H1): settings, server, local repositories, push log.
 * Client side (H2): discovery, remote hub API, publish.
 *
 * Server HTTP API (served by H1, consumed by H2), all JSON:
 * - `GET  /api/info`                                  -> { name, version }
 * - `GET  /api/repos`                                 -> HubRepository[]
 * - `POST /api/repos` { name, description? }          -> HubRepository (409 if exists)
 * - `GET  /api/repos/:name/log?ref=&limit=&skip=`     -> Commit[]
 * - `GET  /api/repos/:name/commits/:sha/files`        -> CommittedFile[]
 * - `GET  /api/repos/:name/commits/:sha/diff?path=`   -> FileDiff
 * - Git Smart HTTP under `/:name.git/...` (info/refs, git-upload-pack, git-receive-pack)
 * LAN discovery: UDP broadcast on port 47321, JSON
 * `{ "type": "ghp-hub", "name": string, "port": number, "version": string }` every 5 s.
 */
export interface HubIpc {
  'hub:getSettings': () => HubSettings
  'hub:updateSettings': (patch: Partial<HubSettings>) => HubSettings
  'hub:status': () => HubServerStatus
  'hub:listLocalRepositories': () => ReadonlyArray<HubRepository>
  'hub:createLocalRepository': (name: string, description?: string) => HubRepository
  /** Moves the bare repository into the hub's trash folder (host only). */
  'hub:deleteLocalRepository': (name: string) => void
  /** Bundles every hub repository into `backupDirectory` now (N6). Returns the last backup time. */
  'hub:backupNow': () => { at: number; repositories: number }
  'hub:pushLog': (query: { repository?: string; limit: number }) => ReadonlyArray<HubPushRecord>

  'hub:discovered': () => ReadonlyArray<DiscoveredHub>
  'hub:addManual': (url: string) => DiscoveredHub
  'hub:removeManual': (id: string) => void
  'hub:listRemoteRepositories': (hubUrl: string) => ReadonlyArray<HubRepository>
  'hub:createRemoteRepository': (
    hubUrl: string,
    name: string,
    description?: string
  ) => HubRepository
  'hub:remoteLog': (
    hubUrl: string,
    repository: string,
    query: { ref?: string; limit: number; skip?: number }
  ) => ReadonlyArray<Commit>
  'hub:remoteCommitFiles': (
    hubUrl: string,
    repository: string,
    sha: string
  ) => ReadonlyArray<CommittedFile>
  'hub:remoteCommitDiff': (
    hubUrl: string,
    repository: string,
    sha: string,
    path: string
  ) => FileDiff
  /** Creates the repository on the hub, adds it as remote `origin` (or `hub` if origin exists) and pushes. */
  'hub:publish': (
    repoId: string,
    input: { hubUrl: string; name: string; description?: string; opId: string }
  ) => void
}

export interface HubEvents {
  'hub:statusChanged': HubServerStatus
  'hub:discoveredChanged': ReadonlyArray<DiscoveredHub>
  'hub:pushReceived': HubPushRecord
}
