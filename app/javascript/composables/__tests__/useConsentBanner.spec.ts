import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useSettingsStore } from '@/stores/settings.store'
import { useConsentBanner } from '../useConsentBanner'

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {}

  return {
    getItem: (key: string) => store[key] || null,
    setItem: (key: string, value: string) => {
      store[key] = value
    },
    removeItem: (key: string) => {
      delete store[key]
    },
    clear: () => {
      store = {}
    },
  }
})()

Object.defineProperty(window, 'localStorage', {
  value: localStorageMock,
})

vi.mock('@/apis/settings.api', () => ({
  fetchConsentBanner: vi.fn(),
}))

describe('useConsentBanner', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    localStorageMock.clear()
    vi.clearAllMocks()
  })

  describe('hasAcknowledged', () => {
    it('returns false when no acknowledgment exists', () => {
      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 1, content: 'Test' }

      const { hasAcknowledged } = useConsentBanner()
      expect(hasAcknowledged.value).toBe(false)
    })

    it('returns false when version mismatch', () => {
      localStorageMock.setItem('vulcan-consent-v1', Date.now().toString())

      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 2, content: 'Test' }

      const { hasAcknowledged } = useConsentBanner()
      expect(hasAcknowledged.value).toBe(false)
    })

    it('returns true when version matches', () => {
      localStorageMock.setItem('vulcan-consent-v1', Date.now().toString())

      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 1, content: 'Test' }

      const { hasAcknowledged } = useConsentBanner()
      expect(hasAcknowledged.value).toBe(true)
    })

    it('returns true when banner is disabled', () => {
      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: false, version: 1, content: '' }

      const { hasAcknowledged } = useConsentBanner()
      expect(hasAcknowledged.value).toBe(true)
    })

    it('returns true when no banner configuration exists', () => {
      const { hasAcknowledged } = useConsentBanner()
      expect(hasAcknowledged.value).toBe(true) // No banner = no acknowledgment needed
    })
  })

  describe('acknowledge', () => {
    it('saves acknowledgment to localStorage with version', () => {
      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 2, content: 'Test' }

      const { acknowledge, hasAcknowledged } = useConsentBanner()

      expect(hasAcknowledged.value).toBe(false)

      acknowledge()

      expect(localStorageMock.getItem('vulcan-consent-v2')).toBeTruthy()
      expect(hasAcknowledged.value).toBe(true)
    })

    it('saves timestamp as acknowledgment value', () => {
      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 1, content: 'Test' }

      const now = Date.now()
      vi.spyOn(Date, 'now').mockReturnValue(now)

      const { acknowledge } = useConsentBanner()
      acknowledge()

      expect(localStorageMock.getItem('vulcan-consent-v1')).toBe(now.toString())
    })

    it('does nothing if no banner configuration', () => {
      const { acknowledge } = useConsentBanner()
      acknowledge() // Should not throw

      expect(localStorageMock.getItem('vulcan-consent-v1')).toBeNull()
    })
  })

  describe('fetchBanner', () => {
    it('fetches banner from store', async () => {
      const settingsStore = useSettingsStore()
      const fetchSpy = vi.spyOn(settingsStore, 'fetchConsentBanner').mockResolvedValue({} as any)

      const { fetchBanner } = useConsentBanner()
      await fetchBanner()

      expect(fetchSpy).toHaveBeenCalledOnce()
    })
  })

  describe('reactive updates', () => {
    it('updates hasAcknowledged when store changes', () => {
      const settingsStore = useSettingsStore()
      const { hasAcknowledged } = useConsentBanner()

      expect(hasAcknowledged.value).toBe(true) // No banner initially

      settingsStore.consentBanner = { enabled: true, version: 1, content: 'Test' }

      expect(hasAcknowledged.value).toBe(false) // Now requires acknowledgment
    })

    it('updates hasAcknowledged after acknowledge()', () => {
      const settingsStore = useSettingsStore()
      settingsStore.consentBanner = { enabled: true, version: 1, content: 'Test' }

      const { hasAcknowledged, acknowledge } = useConsentBanner()

      expect(hasAcknowledged.value).toBe(false)

      acknowledge()

      expect(hasAcknowledged.value).toBe(true)
    })
  })
})
