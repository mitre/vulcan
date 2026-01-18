/**
 * useAdminDashboard Composable
 *
 * Provides reactive interface for admin dashboard stats.
 * Wraps admin store with business logic and computed properties.
 */

import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useAdminStore } from '@/stores/admin.store'

export function useAdminDashboard() {
  const store = useAdminStore()
  const { stats, statsLoading, statsError } = storeToRefs(store)

  // Computed properties for easy access
  const userStats = computed(() => stats.value?.users ?? null)
  const projectStats = computed(() => stats.value?.projects ?? null)
  const stigStats = computed(() => stats.value?.stigs ?? null)
  const srgStats = computed(() => stats.value?.srgs ?? null)
  const componentStats = computed(() => stats.value?.components ?? null)
  const recentActivity = computed(() => stats.value?.recent_activity ?? [])

  // Derived stats
  const totalBenchmarks = computed(() => {
    if (!stats.value) return 0
    return stats.value.stigs.total + stats.value.srgs.total
  })

  /**
   * Load dashboard stats
   */
  async function loadStats(): Promise<void> {
    try {
      await store.fetchStats()
    }
    catch {
      // Error is already set in store, just swallow the throw
    }
  }

  /**
   * Refresh stats (clear cache and reload)
   */
  async function refresh(): Promise<void> {
    store.clearStats()
    await loadStats()
  }

  /**
   * Format relative time for activity display
   */
  function timeAgo(dateStr: string): string {
    const date = new Date(dateStr)
    const now = new Date()
    const seconds = Math.floor((now.getTime() - date.getTime()) / 1000)

    if (seconds < 60) return 'just now'
    if (seconds < 3600) return `${Math.floor(seconds / 60)} min ago`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} hours ago`
    return `${Math.floor(seconds / 86400)} days ago`
  }

  return {
    // State
    stats,
    loading: statsLoading,
    error: statsError,

    // Computed
    userStats,
    projectStats,
    stigStats,
    srgStats,
    componentStats,
    recentActivity,
    totalBenchmarks,

    // Actions
    loadStats,
    refresh,

    // Utilities
    timeAgo,
  }
}
