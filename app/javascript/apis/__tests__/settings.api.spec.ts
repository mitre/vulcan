import { beforeEach, describe, expect, it, vi } from 'vitest'
import { http } from '@/services/http.service'
import { fetchConsentBanner } from '../settings.api'

vi.mock('@/services/http.service', () => ({
  http: {
    get: vi.fn(),
  },
}))

describe('settings.api', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('fetchConsentBanner', () => {
    it('calls GET /api/settings/consent_banner', async () => {
      vi.mocked(http.get).mockResolvedValue({
        data: { enabled: true, version: 1, content: '## Test' },
        status: 200,
      })

      await fetchConsentBanner()

      expect(http.get).toHaveBeenCalledWith('/api/settings/consent_banner')
    })

    it('returns consent banner configuration', async () => {
      const mockData = {
        enabled: true,
        version: 2,
        content: '## Terms\n\nTest content',
      }

      vi.mocked(http.get).mockResolvedValue({
        data: mockData,
        status: 200,
      })

      const result = await fetchConsentBanner()

      expect(result.data.enabled).toBe(true)
      expect(result.data.version).toBe(2)
      expect(result.data.content).toBe('## Terms\n\nTest content')
    })

    it('returns disabled configuration when banner is disabled', async () => {
      vi.mocked(http.get).mockResolvedValue({
        data: { enabled: false, version: 1, content: '' },
        status: 200,
      })

      const result = await fetchConsentBanner()

      expect(result.data.enabled).toBe(false)
      expect(result.data.version).toBe(1)
      expect(result.data.content).toBe('')
    })

    it('handles network errors', async () => {
      vi.mocked(http.get).mockRejectedValue(new Error('Network error'))

      await expect(fetchConsentBanner()).rejects.toThrow('Network error')
    })

    it('handles server errors', async () => {
      vi.mocked(http.get).mockRejectedValue({
        response: { status: 500, data: { error: 'Internal server error' } },
      })

      await expect(fetchConsentBanner()).rejects.toMatchObject({
        response: { status: 500 },
      })
    })

    it('returns markdown content with special characters', async () => {
      const markdownContent = '## Warning\n\n**Bold** text with:\n\n- List items\n- Special chars: `:` and `#`'

      vi.mocked(http.get).mockResolvedValue({
        data: { enabled: true, version: 1, content: markdownContent },
        status: 200,
      })

      const result = await fetchConsentBanner()

      expect(result.data.content).toBe(markdownContent)
      expect(result.data.content).toContain('**Bold**')
      expect(result.data.content).toContain('- List items')
    })
  })
})
