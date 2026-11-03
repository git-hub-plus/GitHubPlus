import { createServer, type IncomingHttpHeaders, type Server } from 'node:http'
import type { AddressInfo } from 'node:net'
import Anthropic from '@anthropic-ai/sdk'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { AnthropicProvider } from '../../../src/main/ai/anthropic'
import { OpenAiCompatibleProvider } from '../../../src/main/ai/openai-compatible'
import { commitSystemPrompt, parseMessage } from '../../../src/main/ai/provider'
import type { AiSettings } from '../../../src/shared/ipc/integrations'

const settings: AiSettings = { provider: 'anthropic', hasApiKey: true }
const secret = 'test-secret-never-return'
const payload = '+private-diff-never-return-on-error'
function claude(response: unknown) {
  const create = vi.fn().mockResolvedValue(response)
  const factory = vi.fn(
    () => ({ beta: { messages: { create } } }) as unknown as Pick<Anthropic, 'beta'>
  )
  return { provider: new AnthropicProvider(factory), create, factory }
}

describe('Anthropic commit provider', () => {
  it('uses the requested SDK beta parameters and only text response blocks', async () => {
    const { provider, create, factory } = claude({
      stop_reason: 'end_turn',
      content: [
        { type: 'thinking', thinking: 'do not output this' },
        { type: 'text', text: '{"summary":"Explain selected change",' },
        { type: 'text', text: '"description":"What changed and why."}' },
      ],
    })
    expect(await provider.generate(settings, secret, payload)).toEqual({
      summary: 'Explain selected change',
      description: 'What changed and why.',
    })
    expect(factory).toHaveBeenCalledWith(secret)
    expect(create).toHaveBeenCalledWith({
      model: 'claude-opus-5-5',
      max_tokens: 16000,
      output_config: { effort: 'low' },
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',
      system: commitSystemPrompt,
      messages: [{ role: 'user', content: payload }],
    })
    const args = create.mock.calls[0][0]
    expect(args).not.toHaveProperty('thinking')
    expect(args).not.toHaveProperty('temperature')
    expect(args).not.toHaveProperty('top_p')
  })
  it('honors a custom model and falls back to first line plus body', async () => {
    const { provider, create } = claude({
      stop_reason: 'end_turn',
      content: [{ type: 'text', text: 'Fix file copying\n\nKeep existing files intact.' }],
    })
    expect(
      await provider.generate({ ...settings, model: 'claude-haiku-5-5' }, secret, payload)
    ).toEqual({ summary: 'Fix file copying', description: 'Keep existing files intact.' })
    expect(create.mock.calls[0][0].model).toBe('claude-haiku-5-5')
  })
  it('reports refusal before parsing its content', async () => {
    const { provider } = claude({
      stop_reason: 'refusal',
      content: [{ type: 'text', text: secret + payload }],
    })
    await expect(provider.generate(settings, secret, payload)).rejects.toMatchObject({
      kind: 'invalid-argument',
    })
  })
  it('requires a key without constructing a client', async () => {
    const { provider, factory } = claude({})
    await expect(provider.generate(settings, undefined, payload)).rejects.toMatchObject({
      kind: 'authentication-failed',
    })
    expect(factory).not.toHaveBeenCalled()
  })
  const headers = new Headers()
  it.each([
    [
      'authentication',
      new Anthropic.AuthenticationError(401, {}, secret + payload, headers),
      'authentication-failed',
    ],
    ['rate limit', new Anthropic.RateLimitError(429, {}, secret + payload, headers), 'network'],
    [
      'internal server',
      new Anthropic.InternalServerError(500, {}, secret + payload, headers),
      'network',
    ],
    ['overload', new Anthropic.InternalServerError(529, {}, secret + payload, headers), 'network'],
    ['connection', new Anthropic.APIConnectionError({ message: secret + payload }), 'network'],
    ['timeout', new Anthropic.APIConnectionTimeoutError({ message: secret + payload }), 'network'],
    [
      'bad request',
      new Anthropic.BadRequestError(400, {}, secret + payload, headers),
      'invalid-argument',
    ],
    ['other API error', new Anthropic.APIError(418, {}, secret + payload, headers), 'internal'],
    ['unknown error', new Error(secret + payload), 'internal'],
  ])('maps %s by SDK class without exposing request data', async (_label, error, kind) => {
    const { provider, create } = claude({})
    create.mockRejectedValue(error)
    const result = await provider
      .generate(settings, secret, payload)
      .catch((failure: unknown) => failure)
    expect(result).toMatchObject({ kind })
    expect(JSON.stringify(result)).not.toContain(secret)
    expect(JSON.stringify(result)).not.toContain(payload)
    expect(String(result)).not.toContain(secret)
    expect(String(result)).not.toContain(payload)
  })
})

describe('OpenAI compatible provider', () => {
  const servers: Server[] = []
  afterEach(async () => {
    vi.restoreAllMocks()
    await Promise.all(
      servers.splice(0).map(
        (server) =>
          new Promise<void>((resolve, reject) => {
            server.closeAllConnections()
            server.close((error) => (error ? reject(error) : resolve()))
          })
      )
    )
  })
  async function server(
    status = 200,
    result: unknown = {
      choices: [
        { message: { content: '{"summary":"Add selected files","description":"Explain why."}' } },
      ],
    }
  ) {
    let received:
      { url?: string; method?: string; headers: IncomingHttpHeaders; body: unknown } | undefined
    const instance = createServer(async (request, response) => {
      const chunks: Buffer[] = []
      for await (const chunk of request) chunks.push(Buffer.from(chunk))
      received = {
        url: request.url,
        method: request.method,
        headers: request.headers,
        body: JSON.parse(Buffer.concat(chunks).toString()),
      }
      response.writeHead(status, { 'Content-Type': 'application/json' })
      response.end(JSON.stringify(result))
    })
    servers.push(instance)
    await new Promise<void>((resolve) => instance.listen(0, '127.0.0.1', resolve))
    return {
      settings: {
        provider: 'openai-compatible',
        hasApiKey: false,
        baseUrl: `http://127.0.0.1:${(instance.address() as AddressInfo).port}/v1/`,
        model: 'test-model',
      } satisfies AiSettings,
      received: () => received,
    }
  }
  it.each([undefined, secret])(
    'sends selected payload to a local server with optional authorization (%s)',
    async (key) => {
      const local = await server()
      expect(await new OpenAiCompatibleProvider().generate(local.settings, key, payload)).toEqual({
        summary: 'Add selected files',
        description: 'Explain why.',
      })
      expect(local.received()).toMatchObject({
        url: '/v1/chat/completions',
        method: 'POST',
        body: {
          model: 'test-model',
          messages: [
            { role: 'system', content: commitSystemPrompt },
            { role: 'user', content: payload },
          ],
        },
      })
      expect(local.received()?.headers.authorization).toBe(key ? `Bearer ${key}` : undefined)
    }
  )
  it.each([
    [401, 'authentication-failed'],
    [403, 'authentication-failed'],
    [429, 'network'],
    [500, 'network'],
    [400, 'invalid-argument'],
  ])('maps HTTP %s without returning its body', async (status, kind) => {
    const local = await server(Number(status), { error: secret + payload })
    const result = await new OpenAiCompatibleProvider()
      .generate(local.settings, secret, payload)
      .catch((failure: unknown) => failure)
    expect(result).toMatchObject({ kind })
    expect(String(result)).not.toContain(secret)
    expect(String(result)).not.toContain(payload)
  })
  it('rejects a response without text content', async () => {
    const local = await server(200, { choices: [] })
    await expect(
      new OpenAiCompatibleProvider().generate(local.settings, undefined, payload)
    ).rejects.toMatchObject({ kind: 'invalid-argument' })
  })
  it('sets the 60 second timeout and sanitizes connection failures', async () => {
    const timeout = vi.spyOn(AbortSignal, 'timeout')
    const request = vi.fn<typeof fetch>().mockRejectedValue(new Error(secret + payload))
    const provider = new OpenAiCompatibleProvider(request)
    await expect(
      provider.generate({ provider: 'openai-compatible', hasApiKey: false }, undefined, payload)
    ).rejects.toMatchObject({ kind: 'network' })
    expect(timeout).toHaveBeenCalledWith(60_000)
    expect(request.mock.calls[0][1]?.signal).toBeInstanceOf(AbortSignal)
    expect(request.mock.calls[0][1]?.redirect).toBe('error')
  })
  it('rejects unsafe URL credentials and schemes before fetching', async () => {
    const request = vi.fn<typeof fetch>()
    for (const baseUrl of [
      'file:///private',
      `http://${secret}@localhost/v1`,
      'http://localhost/v1?secret=value',
    ]) {
      await expect(
        new OpenAiCompatibleProvider(request).generate(
          { provider: 'openai-compatible', hasApiKey: false, baseUrl },
          undefined,
          payload
        )
      ).rejects.toMatchObject({ kind: 'invalid-argument' })
    }
    expect(request).not.toHaveBeenCalled()
  })
})

describe('commit response parsing', () => {
  it('accepts fenced JSON and bounds summary length', () => {
    expect(parseMessage('```json\n{"summary":"A summary","description":"A body"}\n```')).toEqual({
      summary: 'A summary',
      description: 'A body',
    })
    expect(parseMessage('x'.repeat(100)).summary).toHaveLength(72)
  })
  it('rejects an empty response', () => {
    expect(() => parseMessage('')).toThrow('empty commit message')
  })
})
