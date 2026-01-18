/**
 * Settings Store
 * Public application settings (no auth required)
 *
 * Uses Composition API pattern (Vue 3 standard)
 */

import type { IConsentBanner } from '@/apis/settings.api'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchConsentBanner as apiFetchConsentBanner } from '@/apis/settings.api'
import { withAsyncAction } from '@/utils'

export const useSettingsStore = defineStore('settings.store', () => {
  // State
  const consentBanner = ref<IConsentBanner | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Actions

  /**
   * Fetch consent banner configuration from API
   */
  async function fetchConsentBanner() {
    return withAsyncAction(loading, error, 'Failed to fetch consent banner', async () => {
      const response = await apiFetchConsentBanner()
      consentBanner.value = response.data
      return response
    })
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    consentBanner.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    consentBanner,
    loading,
    error,

    // Actions
    fetchConsentBanner,
    reset,
  }
})
