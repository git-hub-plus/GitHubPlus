import { Emitter, Disposable } from 'event-kit'
import { ReleaseSummary } from '../../models/release-notes'

/** The last version a showcase was seen. */
export const lastShowCaseVersionSeen = 'version-of-last-showcase'

/** The states the auto updater can be in. */
export enum UpdateStatus {
  /** The auto updater is checking for updates. */
  CheckingForUpdates,

  /** An update is available and will begin downloading. */
  UpdateAvailable,

  /** No update is available. */
  UpdateNotAvailable,

  /** An update has been downloaded and is ready to be installed. */
  UpdateReady,

  /** We have not checked for an update yet. */
  UpdateNotChecked,
}

export interface IUpdateState {
  status: UpdateStatus
  lastSuccessfulCheck: Date | null
  isX64ToARM64ImmediateAutoUpdate: boolean
  newReleases: ReadonlyArray<ReleaseSummary> | null
  prioritizeUpdate: boolean
  prioritizeUpdateInfoUrl: string | undefined
}

/** Update compatibility API. GitHub+ does not contact update services. */
class UpdateStore {
  private readonly emitter = new Emitter()

  public get prioritizeUpdate() {
    return false
  }
  public get prioritizeUpdateInfoUrl(): string | undefined {
    return undefined
  }

  public onDidChange(fn: (state: IUpdateState) => void): Disposable {
    return this.emitter.on('did-change', fn)
  }

  public onError(fn: (error: Error) => void): Disposable {
    return this.emitter.on('error', fn)
  }

  public get state(): IUpdateState {
    return {
      status: UpdateStatus.UpdateNotAvailable,
      lastSuccessfulCheck: null,
      newReleases: null,
      isX64ToARM64ImmediateAutoUpdate: false,
      prioritizeUpdate: false,
      prioritizeUpdateInfoUrl: undefined,
    }
  }

  public async checkForUpdates(
    _inBackground: boolean,
    _skipGuidCheck: boolean
  ) {
    this.emitter.emit('did-change', this.state)
  }

  public quitAndInstallUpdate() {
    /* Updates are disabled. */
  }
  public async isUpdateShowcase() {
    return false
  }
  public setIsx64ToARM64ImmediateAutoUpdate(_value: boolean) {
    /* Updates are disabled. */
  }
  public setPrioritizeUpdate(_value: boolean) {
    /* Updates are disabled. */
  }
  public setPrioritizeUpdateInfoUrl(_value: string | undefined) {
    /* Updates are disabled. */
  }
}

/** The store which contains the current state of the auto updater. */
export const updateStore = new UpdateStore()
