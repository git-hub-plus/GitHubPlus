/**
 * Registers the `git:*` IPC handlers declared in `src/shared/ipc/git.ts`.
 *
 * N1 fills this in: each handler group lives in its own file under
 * `src/main/git/handlers/` and is registered from here.
 */
export function registerGitHandlers(): void {
  // Intentionally empty until the git layer is ported (N1).
}
