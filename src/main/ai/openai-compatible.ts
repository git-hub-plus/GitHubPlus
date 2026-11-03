import { HandlerError } from '@shared/errors'
import type { AiSettings } from '@shared/ipc/integrations'
import { commitSystemPrompt, parseMessage, type CommitMessageProvider } from './provider'

export class OpenAiCompatibleProvider implements CommitMessageProvider {
  constructor(private readonly request: typeof fetch = fetch) {}
  async generate(settings: AiSettings, apiKey: string | undefined, payload: string) {
    try {
      const base = new URL(settings.baseUrl || 'http://localhost:1234/v1')
      if (
        !['http:', 'https:'].includes(base.protocol) ||
        base.username ||
        base.password ||
        base.search ||
        base.hash
      )
        throw new HandlerError(
          'invalid-argument',
          'Use an HTTP(S) server address without credentials or a query.'
        )
      const response = await this.request(`${base.href.replace(/\/$/, '')}/chat/completions`, {
        method: 'POST',
        signal: AbortSignal.timeout(60_000),
        redirect: 'error',
        headers: {
          'Content-Type': 'application/json',
          ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
        },
        body: JSON.stringify({
          model: settings.model || 'local-model',
          messages: [
            { role: 'system', content: commitSystemPrompt },
            { role: 'user', content: payload },
          ],
        }),
      })
      if (!response.ok) {
        const kind =
          response.status === 401 || response.status === 403
            ? 'authentication-failed'
            : response.status === 429 || response.status >= 500
              ? 'network'
              : 'invalid-argument'
        throw new HandlerError(kind, 'The AI server could not complete the request.')
      }
      const result = (await response.json()) as {
        choices?: Array<{ message?: { content?: unknown } }>
      }
      const content = result.choices?.[0]?.message?.content
      if (typeof content !== 'string')
        throw new HandlerError('invalid-argument', 'The AI server returned an invalid response.')
      return parseMessage(content)
    } catch (error) {
      if (error instanceof HandlerError) throw error
      throw new HandlerError('network', 'Could not reach the AI server or read its response.')
    }
  }
}
