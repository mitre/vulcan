/**
 * Consent Banner Composable
 * Handles acknowledgment tracking via localStorage
 *
 * Architecture: Wraps settings store, provides reactive consent state
 */

import { computed, ref } from 'vue'
import { useSettingsStore } from '@/stores/settings.store'

const STORAGE_KEY_PREFIX = 'vulcan-consent-v'

/**
 * Get localStorage key for specific version
 */
function getStorageKey(version: number): string {
  return `${STORAGE_KEY_PREFIX}${version}`
}

/**
 * Check if user has acknowledged consent for a specific version
 */
function hasAcknowledgedVersion(version: number): boolean {
  const key = getStorageKey(version)
  return localStorage.getItem(key) !== null
}

/**
 * Save acknowledgment to localStorage
 */
function saveAcknowledgment(version: number): void {
  const key = getStorageKey(version)
  localStorage.setItem(key, Date.now().toString())
}

export function useConsentBanner() {
  const settingsStore = useSettingsStore()

  // Reactive trigger for localStorage changes
  const acknowledgmentTrigger = ref(0)

  /**
   * Has user acknowledged the current consent banner?
   * Returns true if:
   * - Banner is disabled
   * - No banner configuration exists
   * - User has acknowledged current version
   */
  const hasAcknowledged = computed(() => {
    // Read trigger to make this reactive to localStorage changes
    acknowledgmentTrigger.value // eslint-disable-line @typescript-eslint/no-unused-expressions

    const banner = settingsStore.consentBanner

    // No banner = no acknowledgment needed
    if (!banner) {
      return true
    }

    // Disabled banner = no acknowledgment needed
    if (!banner.enabled) {
      return true
    }

    // Check if user has acknowledged this specific version
    return hasAcknowledgedVersion(banner.version)
  })

  /**
   * Acknowledge current consent banner
   * Saves acknowledgment to localStorage with timestamp
   */
  function acknowledge() {
    const banner = settingsStore.consentBanner
    if (!banner) {
      return
    }

    saveAcknowledgment(banner.version)
    acknowledgmentTrigger.value++ // Trigger reactivity
  }

  /**
   * Fetch banner configuration from API
   */
  async function fetchBanner() {
    return settingsStore.fetchConsentBanner()
  }

  return {
    // State
    hasAcknowledged,
    consentBanner: computed(() => settingsStore.consentBanner),
    loading: computed(() => settingsStore.loading),

    // Actions
    acknowledge,
    fetchBanner,
  }
}
