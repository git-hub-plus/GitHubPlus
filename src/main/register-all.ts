import { register as registerAi } from './ai/register'
import { register as registerFiles } from './files/register'
import { register as registerGitHub } from './github/register'
import { register as registerHubClient } from './hub/client/register'
import { register as registerHubServer } from './hub/server/register'
import { register as registerAdvanced } from './git/handlers/advanced'
import { register as registerIdentity } from './git/handlers/identity'
import { register as registerLfsSubmodules } from './git/handlers/lfs-submodules'
import { registerGitHandlers } from './git/register'
import { registerAppHandlers } from './handlers/app'

/**
 * Registers every IPC handler group. Each group file has a single owner, so
 * parallel workers never edit the same registration code.
 */
export function registerAllHandlers(): void {
  registerAppHandlers()
  registerGitHandlers()
  registerIdentity()
  registerAdvanced()
  registerLfsSubmodules()
  registerFiles()
  registerHubServer()
  registerHubClient()
  registerGitHub()
  registerAi()
}
