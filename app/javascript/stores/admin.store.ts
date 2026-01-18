/**
 * Admin Store
 *
 * Pinia store for admin dashboard stats and settings.
 * Caches data and manages loading/error states.
 */

import type { AdminSettings, AdminStats } from '@/apis/admin.api'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { adminApi } from '@/apis/admin.api'

export const useAdminStore = defineStore('admin', () => {
  // State
  const stats = ref<AdminStats | null>(null)
  const settings = ref<AdminSettings | null>(null)
  const statsLoading = ref(false)
  const settingsLoading = ref(false)
  const statsError = ref<string | null>(null)
  const settingsError = ref<string | null>(null)

  /**
   * Fetch dashboard stats
   */
  async function fetchStats(): Promise<void> {
    statsLoading.value = true
    statsError.value = null

    try {
      const response = await adminApi.getStats()
      stats.value = response.data
    }
    catch (error) {
      statsError.value = error instanceof Error ? error.message : 'Failed to load stats'
      throw error
    }
    finally {
      statsLoading.value = false
    }
  }

  /**
   * Fetch settings
   */
  async function fetchSettings(): Promise<void> {
    settingsLoading.value = true
    settingsError.value = null

    try {
      const response = await adminApi.getSettings()
      settings.value = response.data
    }
    catch (error) {
      settingsError.value = error instanceof Error ? error.message : 'Failed to load settings'
      throw error
    }
    finally {
      settingsLoading.value = false
    }
  }

  /**
   * Clear cached stats (force refresh on next fetch)
   */
  function clearStats(): void {
    stats.value = null
    statsError.value = null
  }

  /**
   * Clear cached settings (force refresh on next fetch)
   */
  function clearSettings(): void {
    settings.value = null
    settingsError.value = null
  }

  return {
    // State
    stats,
    settings,
    statsLoading,
    settingsLoading,
    statsError,
    settingsError,

    // Actions
    fetchStats,
    fetchSettings,
    clearStats,
    clearSettings,
  }
})
