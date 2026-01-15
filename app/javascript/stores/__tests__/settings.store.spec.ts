import { beforeEach, describe, expect, it, vi } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import * as settingsApi from '@/apis/settings.api'
import { useSettingsStore } from '../settings.store'

vi.mock('@/apis/settings.api')

describe('settings.store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('starts with null consentBanner', () => {
      const store = useSettingsStore()
      expect(store.consentBanner).toBeNull()
    })

    it('starts with loading false', () => {
      const store = useSettingsStore()
      expect(store.loading).toBe(false)
    })

    it('starts with no error', () => {
      const store = useSettingsStore()
      expect(store.error).toBeNull()
    })
  })

  describe('fetchConsentBanner', () => {
    it('fetches and stores consent banner configuration', async () => {
      const mockData = {
        enabled: true,
        version: 2,
        content: '## Test Banner',
      }

      vi.mocked(settingsApi.fetchConsentBanner).mockResolvedValue({
        data: mockData,
        status: 200,
      } as any)

      const store = useSettingsStore()
      await store.fetchConsentBanner()

      expect(store.consentBanner).toEqual(mockData)
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })

    it('sets loading to true during fetch', async () => {
      vi.mocked(settingsApi.fetchConsentBanner).mockImplementation(
        () => new Promise(resolve => setTimeout(() => resolve({
          data: { enabled: false, version: 1, content: '' },
          status: 200,
        } as any), 100)),
      )

      const store = useSettingsStore()
      const promise = store.fetchConsentBanner()

      expect(store.loading).toBe(true)

      await promise
    })

    it('sets loading to false after successful fetch', async () => {
      vi.mocked(settingsApi.fetchConsentBanner).mockResolvedValue({
        data: { enabled: false, version: 1, content: '' },
        status: 200,
      } as any)

      const store = useSettingsStore()
      await store.fetchConsentBanner()

      expect(store.loading).toBe(false)
    })

    it('handles disabled consent banner', async () => {
      const mockData = {
        enabled: false,
        version: 1,
        content: '',
      }

      vi.mocked(settingsApi.fetchConsentBanner).mockResolvedValue({
        data: mockData,
        status: 200,
      } as any)

      const store = useSettingsStore()
      await store.fetchConsentBanner()

      expect(store.consentBanner).toEqual(mockData)
      expect(store.consentBanner?.enabled).toBe(false)
    })

    it('handles API errors', async () => {
      vi.mocked(settingsApi.fetchConsentBanner).mockRejectedValue(
        new Error('Network error'),
      )

      const store = useSettingsStore()

      await expect(store.fetchConsentBanner()).rejects.toThrow('Network error')

      expect(store.loading).toBe(false)
      expect(store.error).toBe('Network error') // extractErrorMessage extracts actual error
      expect(store.consentBanner).toBeNull()
    })

    it('preserves markdown content', async () => {
      const mockData = {
        enabled: true,
        version: 1,
        content: '## Header\n\n**Bold** text with:\n\n- Item 1\n- Item 2',
      }

      vi.mocked(settingsApi.fetchConsentBanner).mockResolvedValue({
        data: mockData,
        status: 200,
      } as any)

      const store = useSettingsStore()
      await store.fetchConsentBanner()

      expect(store.consentBanner?.content).toContain('## Header')
      expect(store.consentBanner?.content).toContain('**Bold**')
      expect(store.consentBanner?.content).toContain('- Item 1')
    })
  })

  describe('reset', () => {
    it('clears consent banner data', async () => {
      vi.mocked(settingsApi.fetchConsentBanner).mockResolvedValue({
        data: { enabled: true, version: 1, content: '## Test' },
        status: 200,
      } as any)

      const store = useSettingsStore()
      await store.fetchConsentBanner()

      store.reset()

      expect(store.consentBanner).toBeNull()
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
