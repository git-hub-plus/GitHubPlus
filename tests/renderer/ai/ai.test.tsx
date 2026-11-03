// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { AiCommitButton } from '@renderer/components/ai/AiCommitButton'
import { AiSettingsSection } from '@renderer/components/ai/AiSettingsSection'
import { ChangesView } from '@renderer/components/changes/ChangesView'
import { useAiStore } from '@renderer/state/ai-store'
import { useChangesStore } from '@renderer/state/changes-store'
import { useRepoStore } from '@renderer/state/repo-store'
import { useToastStore } from '@renderer/state/toast-store'
import type { AiSettings } from '@shared/ipc/integrations'
import { installFakeBridge } from '../helpers/fake-bridge'
import { setup } from '../app/test-utils'
import { diff, status } from '../changes/fixtures'

const input = {
  files: [
    { path: 'a.ts', selection: { defaultSelectionType: 'all' as const, divergingLines: [] } },
  ],
}
const message = {
  summary: '선택한 변경 반영',
  description: '선택한 줄을 반영해 동작을 수정합니다.',
}

beforeEach(() => {
  setup()
  useAiStore.setState({ settings: undefined })
  useChangesStore.setState({ repositories: {}, messageDrafts: {} })
})
afterEach(cleanup)

describe('AI commit messages', () => {
  it('hides the button when provider is none', async () => {
    const bridge = installFakeBridge(() => ({ provider: 'none', hasApiKey: false }))
    render(<AiCommitButton repoId="repo" input={input} disabled={false} onGenerated={vi.fn()} />)
    await waitFor(() => expect(bridge.invoke).toHaveBeenCalledWith('ai:getSettings'))
    expect(screen.queryByRole('button', { name: 'AI로 작성' })).toBeNull()
  })

  it('previews the exact payload with truncation and sends only after confirmation', async () => {
    const generated = vi.fn()
    const bridge = installFakeBridge((channel) => {
      if (channel === 'ai:getSettings') return { provider: 'anthropic', hasApiKey: true }
      if (channel === 'ai:previewPayload') return 'a.ts\n+selected\n(이하 생략)'
      return message
    })
    render(<AiCommitButton repoId="repo" input={input} disabled={false} onGenerated={generated} />)
    fireEvent.click(await screen.findByRole('button', { name: 'AI로 작성' }))
    expect(await screen.findByText(/\+selected/)).toBeTruthy()
    expect(screen.getByText(/\(이하 생략\)/)).toBeTruthy()
    expect(
      bridge.invoke.mock.calls.some(([channel]) => channel === 'ai:generateCommitMessage')
    ).toBe(false)
    fireEvent.click(screen.getByRole('button', { name: '보내기' }))
    await waitFor(() => expect(generated).toHaveBeenCalledWith(message))
    expect(bridge.invoke).toHaveBeenCalledWith('ai:generateCommitMessage', 'repo', input)
    expect(screen.queryByRole('dialog')).toBeNull()
  })

  it('shows a changed payload again before generating', async () => {
    let payload = 'old'
    const bridge = installFakeBridge((channel) =>
      channel === 'ai:getSettings' ? { provider: 'anthropic', hasApiKey: true } : payload
    )
    render(<AiCommitButton repoId="repo" input={input} disabled={false} onGenerated={vi.fn()} />)
    fireEvent.click(await screen.findByRole('button', { name: 'AI로 작성' }))
    await screen.findByText('old')
    payload = 'new'
    fireEvent.click(screen.getByRole('button', { name: '보내기' }))
    await screen.findByText('new')
    expect(
      bridge.invoke.mock.calls.some(([channel]) => channel === 'ai:generateCommitMessage')
    ).toBe(false)
  })

  it('reports provider failures through the error toast and keeps the preview', async () => {
    installFakeBridge((channel) => {
      if (channel === 'ai:getSettings') return { provider: 'anthropic', hasApiKey: true }
      if (channel === 'ai:previewPayload') return 'selected'
      throw { kind: 'authentication-failed', message: 'Invalid credentials' }
    })
    render(<AiCommitButton repoId="repo" input={input} disabled={false} onGenerated={vi.fn()} />)
    fireEvent.click(await screen.findByRole('button', { name: 'AI로 작성' }))
    fireEvent.click(await screen.findByRole('button', { name: '보내기' }))
    await waitFor(() => expect(useToastStore.getState().toasts[0]?.kind).toBe('error'))
    expect(useToastStore.getState().toasts[0].message).toBe('repoActions.errors.authentication')
    expect(screen.getByRole('dialog')).toBeTruthy()
  })

  it('fills editable summary and description in the commit form', async () => {
    const bridge = installFakeBridge((channel) => {
      if (channel === 'ai:getSettings') return { provider: 'openai-compatible', hasApiKey: false }
      if (channel === 'ai:previewPayload') return 'selected'
      if (channel === 'ai:generateCommitMessage') return message
      if (channel === 'git:workingDiff') return diff
      return []
    })
    useRepoStore.setState({ status, repoId: 'repo' })
    render(<ChangesView />)
    fireEvent.change(screen.getByLabelText('요약 (필수)'), { target: { value: '기존 초안' } })
    fireEvent.click(await screen.findByRole('button', { name: 'AI로 작성' }))
    fireEvent.click(await screen.findByRole('button', { name: '보내기' }))
    await waitFor(() =>
      expect((screen.getByLabelText('요약 (필수)') as HTMLInputElement).value).toBe(message.summary)
    )
    expect((screen.getByLabelText('설명') as HTMLTextAreaElement).value).toBe(message.description)
    expect(
      bridge.invoke.mock.calls.some(
        ([channel]) => channel === 'git:getIdentity' || channel === 'git:commit'
      )
    ).toBe(false)
    fireEvent.change(screen.getByLabelText('요약 (필수)'), { target: { value: '직접 고친 요약' } })
    expect((screen.getByLabelText('요약 (필수)') as HTMLInputElement).value).toBe('직접 고친 요약')
  })
})

describe('AI settings', () => {
  it('saves a password without retaining it and clears the stored key explicitly', async () => {
    let settings: AiSettings = {
      provider: 'openai-compatible',
      model: 'local',
      baseUrl: 'http://localhost:8080/v1',
      hasApiKey: false,
    }
    const bridge = installFakeBridge((channel, patch) => {
      if (channel === 'ai:getSettings') return settings
      const update = patch as Partial<AiSettings> & { apiKey?: string | null }
      settings = {
        ...settings,
        provider: update.provider ?? settings.provider,
        model: update.model,
        baseUrl: update.baseUrl,
        hasApiKey: update.apiKey === null ? false : !!update.apiKey || settings.hasApiKey,
      }
      return settings
    })
    render(<AiSettingsSection />)
    const key = (await screen.findByLabelText('API 키')) as HTMLInputElement
    expect(key.type).toBe('password')
    fireEvent.change(key, { target: { value: 'test-secret' } })
    fireEvent.click(screen.getByRole('button', { name: '저장' }))
    await waitFor(() => expect(key.value).toBe(''))
    expect(key.placeholder).toBe('저장됨')
    expect(screen.queryByDisplayValue('test-secret')).toBeNull()
    fireEvent.click(screen.getByRole('button', { name: '키 지우기' }))
    await waitFor(() =>
      expect(bridge.invoke).toHaveBeenCalledWith(
        'ai:updateSettings',
        expect.objectContaining({ apiKey: null })
      )
    )
    await waitFor(() => expect(screen.queryByRole('button', { name: '키 지우기' })).toBeNull())
  })

  it('offers Claude models and only shows the server address for OpenAI compatible', async () => {
    installFakeBridge(() => ({ provider: 'anthropic', hasApiKey: false }))
    render(<AiSettingsSection />)
    await screen.findByLabelText('모델')
    expect((screen.getByLabelText('모델') as HTMLInputElement).placeholder).toBe('claude-opus-5-5')
    expect(screen.queryByLabelText('서버 주소')).toBeNull()
    act(() =>
      fireEvent.change(screen.getByLabelText('공급자'), { target: { value: 'openai-compatible' } })
    )
    expect(screen.getByLabelText('서버 주소')).toBeTruthy()
  })
})
