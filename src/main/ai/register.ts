import { app, safeStorage } from 'electron'
import { HandlerError } from '@shared/errors'
import { handle } from '../ipc'
import { getRepository } from '../store/repositories'
import { AnthropicProvider } from './anthropic'
import { OpenAiCompatibleProvider } from './openai-compatible'
import { buildPayload } from './payload'
import type { CommitMessageProvider } from './provider'
import { AiSettingsStore } from './settings'

export function register(
  providers: { anthropic: CommitMessageProvider; 'openai-compatible': CommitMessageProvider } = {
    anthropic: new AnthropicProvider(),
    'openai-compatible': new OpenAiCompatibleProvider(),
  }
): void {
  const store = new AiSettingsStore(app.getPath('userData'), safeStorage)
  handle('ai:getSettings', () => store.get())
  handle('ai:updateSettings', (_event, patch) => store.update(patch))
  const payload = (id: string, input: Parameters<typeof buildPayload>[1]) =>
    buildPayload(getRepository(id).path, input)
  // Keep one bounded snapshot per window; generation sends exactly the reviewed text.
  const previews = new Map<number, { id: string; input: string; text: string; expires: number }>()
  handle('ai:previewPayload', async (event, id, input) => {
    const text = await payload(id, input)
    previews.set(event.sender.id, {
      id,
      input: JSON.stringify(input),
      text,
      expires: Date.now() + 600_000,
    })
    return text
  })
  handle('ai:generateCommitMessage', async (event, id, input) => {
    const settings = await store.get()
    if (settings.provider === 'none')
      throw new HandlerError('invalid-argument', 'Configure an AI provider first.')
    try {
      const preview = previews.get(event.sender.id)
      previews.delete(event.sender.id)
      if (
        !preview ||
        preview.id !== id ||
        preview.input !== JSON.stringify(input) ||
        preview.expires < Date.now() ||
        preview.text !== (await payload(id, input))
      ) {
        throw new HandlerError(
          'invalid-argument',
          'The selected changes have changed. Preview them again before sending.'
        )
      }
      return await providers[settings.provider].generate(
        settings,
        await store.apiKey(),
        preview.text
      )
    } catch (error) {
      if (error instanceof HandlerError) throw error
      throw new HandlerError('internal', 'Could not generate a commit message.')
    }
  })
}
