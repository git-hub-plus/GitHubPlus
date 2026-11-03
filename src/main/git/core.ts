// Ported from GitHub Desktop (MIT): app/src/lib/git/core.ts
// Simplified: no hooks/trampoline/perf wrappers. Authentication is left to the
// credential helper bundled with dugite until GitHub+ adds its own (N5).
import type { ChildProcess } from 'node:child_process'
import { exec, GitError as DugiteError, parseError, type IGitExecutionOptions } from 'dugite'
import type { GitErrorKind } from '@shared/models/git'
import { HandlerError } from '@shared/errors'
import { log } from '../log'

export { DugiteError }

export interface GitOptions {
  /** Exit codes treated as success (default: 0). */
  readonly successExitCodes?: ReadonlySet<number>
  /** Parsed git errors returned as results instead of thrown. */
  readonly expectedErrors?: ReadonlySet<DugiteError>
  readonly env?: Record<string, string | undefined>
  /** Written to stdin. */
  readonly stdin?: string | Buffer
  readonly processCallback?: (process: ChildProcess) => void
  readonly maxBuffer?: number
}

export interface GitResult<T extends string | Buffer = string> {
  readonly stdout: T
  readonly stderr: T
  readonly exitCode: number
  /** Parsed error when the exit code was not a success code. */
  readonly gitError: DugiteError | null
  readonly path: string
}

/** Thrown when git fails unexpectedly; carries the parsed dugite error. */
export class GitError extends Error {
  public constructor(
    public readonly result: GitResult<string>,
    public readonly args: ReadonlyArray<string>
  ) {
    super(`git ${args.join(' ')} failed (${result.exitCode}): ${result.stderr.trim().slice(-500)}`)
    this.name = 'GitError'
  }
}

/**
 * Extra git config/env for a command, e.g. an Authorization header for
 * github.com remotes (N5) or settings for hub remotes (N3). Providers must be
 * fast; they run before every git invocation.
 */
export type GitAuthProvider = (
  args: ReadonlyArray<string>,
  path: string
) => { configArgs?: string[]; env?: Record<string, string> } | undefined

const authProviders: GitAuthProvider[] = []

export function registerGitAuthProvider(provider: GitAuthProvider): () => void {
  authProviders.push(provider)
  return () => {
    const index = authProviders.indexOf(provider)
    if (index >= 0) authProviders.splice(index, 1)
  }
}

const baseEnv = {
  // Never block on an interactive prompt; credential helpers still run.
  GIT_TERMINAL_PROMPT: '0',
  TERM: 'dumb',
  // Keep output machine-readable regardless of the user's locale.
  LC_ALL: 'C',
  LANG: 'C',
}

function toText(value: string | Buffer): string {
  return typeof value === 'string' ? value : value.toString('utf8')
}

/**
 * Runs git in `path`. `name` is a short label for logs (e.g. 'getStatus').
 * Resolves for success exit codes and expected errors, throws GitError otherwise.
 */
export async function git(
  args: string[],
  path: string,
  name: string,
  options?: GitOptions & { encoding?: 'utf8' }
): Promise<GitResult<string>>
export async function git(
  args: string[],
  path: string,
  name: string,
  options: GitOptions & { encoding: 'buffer' }
): Promise<GitResult<Buffer>>
export async function git(
  args: string[],
  path: string,
  name: string,
  options: GitOptions & { encoding?: 'utf8' | 'buffer' } = {}
): Promise<GitResult<string | Buffer>> {
  const successExitCodes = options.successExitCodes ?? new Set([0])
  const extraConfig: string[] = []
  let extraEnv: Record<string, string> = {}
  for (const provider of authProviders) {
    const extra = provider(args, path)
    if (extra?.configArgs) extraConfig.push(...extra.configArgs)
    if (extra?.env) extraEnv = { ...extraEnv, ...extra.env }
  }
  // Logs and errors use `args` only, so provider secrets never reach them.
  const execArgs = [...extraConfig, ...args]
  const execOptions: IGitExecutionOptions = {
    env: { ...baseEnv, ...extraEnv, ...options.env },
    stdin: options.stdin,
    processCallback: options.processCallback,
    maxBuffer: options.maxBuffer ?? (options.encoding === 'buffer' ? Infinity : 256 * 1024 * 1024),
  }
  const result =
    options.encoding === 'buffer'
      ? await exec(execArgs, path, { ...execOptions, encoding: 'buffer' })
      : await exec(execArgs, path, execOptions)

  let gitError: DugiteError | null = null
  if (!successExitCodes.has(result.exitCode)) {
    gitError = parseError(toText(result.stderr)) ?? parseError(toText(result.stdout))
  }
  const gitResult: GitResult<string | Buffer> = { ...result, gitError, path }

  if (successExitCodes.has(result.exitCode)) {
    return gitResult
  }
  if (gitError !== null && options.expectedErrors?.has(gitError)) {
    return gitResult
  }

  const textResult: GitResult<string> = {
    ...gitResult,
    stdout: toText(result.stdout),
    stderr: toText(result.stderr),
  }
  log.warn(
    `${name}: git ${args.join(' ')} exited ${result.exitCode}`,
    textResult.stderr.slice(-1024)
  )
  throw new GitError(textResult, args)
}

/** Maps dugite's parsed errors to the kinds the UI understands. */
export function classifyGitError(error: DugiteError | null): GitErrorKind {
  switch (error) {
    case DugiteError.NotAGitRepository:
      return 'not-a-repository'
    case DugiteError.SSHAuthenticationFailed:
    case DugiteError.SSHPermissionDenied:
    case DugiteError.HTTPSAuthenticationFailed:
      return 'authentication-failed'
    case DugiteError.PushNotFastForward:
      return 'push-needs-pull'
    case DugiteError.PushWithFileSizeExceedingLimit:
    case DugiteError.ProtectedBranchForcePush:
    case DugiteError.ProtectedBranchRequiresReview:
    case DugiteError.ProtectedBranchDeleteRejected:
      return 'push-rejected'
    case DugiteError.MergeConflicts:
    case DugiteError.RebaseConflicts:
    case DugiteError.RevertConflicts:
      return 'merge-conflicts'
    case DugiteError.LocalChangesOverwritten:
    case DugiteError.MergeWithLocalChanges:
    case DugiteError.RebaseWithLocalChanges:
      return 'local-changes-overwritten'
    case DugiteError.BranchAlreadyExists:
      return 'branch-exists'
    case DugiteError.NoMatchingRemoteBranch:
      return 'no-upstream'
    case DugiteError.HostDown:
    case DugiteError.RemoteDisconnection:
    case DugiteError.HTTPSRepositoryNotFound:
    case DugiteError.SSHRepositoryNotFound:
      return 'network'
    default:
      return 'unknown'
  }
}

/**
 * Converts any error from the git layer into a HandlerError for IPC. Use in
 * handlers: `catch (e) { throw toHandlerError(e) }`, or wrap with `withGitErrors`.
 */
export function toHandlerError(error: unknown): unknown {
  if (error instanceof HandlerError) {
    return error
  }
  if (error instanceof GitError) {
    const kind = classifyGitError(error.result.gitError)
    return new HandlerError(kind, error.message, error.result.stderr.trim() || undefined)
  }
  return error
}

/** Runs `fn` and rethrows git failures as HandlerError. */
export async function withGitErrors<T>(fn: () => Promise<T>): Promise<T> {
  try {
    return await fn()
  } catch (error) {
    throw toHandlerError(error)
  }
}
