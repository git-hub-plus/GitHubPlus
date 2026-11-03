import Anthropic from '@anthropic-ai/sdk'
import { HandlerError } from '@shared/errors'
import type { AiSettings } from '@shared/ipc/integrations'
import { commitSystemPrompt, parseMessage, type CommitMessageProvider } from './provider'

type Client = Pick<Anthropic, 'beta'>
export class AnthropicProvider implements CommitMessageProvider {
  constructor(
    private readonly createClient: (apiKey: string) => Client = (apiKey) =>
      new Anthropic({ apiKey })
  ) {}
  async generate(settings: AiSettings, apiKey: string | undefined, payload: string) {
    if (!apiKey) throw new HandlerError('authentication-failed', 'Configure an API key for Claude.')
    try {
      const response = await this.createClient(apiKey).beta.messages.create({
        model: settings.model || 'claude-opus-5-5',
        max_tokens: 16000,
        output_config: { effort: 'low' },
        betas: ['server-side-fallback-2026-07-01'],
        fallbacks: 'default',
        system: commitSystemPrompt,
        messages: [{ role: 'user', content: payload }],
      })
      if (response.stop_reason === 'refusal')
        throw new HandlerError(
          'invalid-argument',
          'Claude declined this request. Review the selected changes.'
        )
      return parseMessage(
        response.content
          .filter((block) => block.type === 'text')
          .map((block) => block.text)
          .join('\n')
      )
    } catch (error) {
      if (error instanceof HandlerError) throw error
      if (error instanceof Anthropic.AuthenticationError)
        throw new HandlerError('authentication-failed', 'Claude authentication failed.')
      if (
        error instanceof Anthropic.RateLimitError ||
        error instanceof Anthropic.InternalServerError ||
        error instanceof Anthropic.APIConnectionError
      )
        throw new HandlerError('network', 'Claude is unavailable. Try again later.')
      if (error instanceof Anthropic.BadRequestError)
        throw new HandlerError('invalid-argument', 'Claude rejected the request settings.')
      // Never propagate SDK messages, response bodies or request metadata (may contain secrets).
      throw new HandlerError('internal', 'Claude could not generate a commit message.')
    }
  }
}
