/**
 * useAdminDashboard Composable Tests
 */

import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { adminApi } from '@/apis/admin.api'

import { useAdminDashboard } from '../useAdminDashboard'

// Mock admin API
vi.mock('@/apis/admin.api', () => ({
  adminApi: {
    getStats: vi.fn(),
    getSettings: vi.fn(),
  },
}))

describe('useAdminDashboard', () => {
  const mockStats = {
    users: { total: 10, local: 8, external: 2, admins: 2, locked: 1 },
    projects: { total: 5, recent: 2 },
    components: { total: 15, released: 3 },
    stigs: { total: 8 },
    srgs: { total: 4 },
    recent_activity: [
      { id: 1, action: 'create', auditable_type: 'Component', auditable_name: 'Test', user_name: 'Admin', created_at: new Date().toISOString() },
    ],
  }

  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('has null stats', () => {
      const { stats, userStats, projectStats, stigStats, srgStats, componentStats, recentActivity } = useAdminDashboard()

      expect(stats.value).toBeNull()
      expect(userStats.value).toBeNull()
      expect(projectStats.value).toBeNull()
      expect(stigStats.value).toBeNull()
      expect(srgStats.value).toBeNull()
      expect(componentStats.value).toBeNull()
      expect(recentActivity.value).toEqual([])
    })

    it('has loading false initially', () => {
      const { loading } = useAdminDashboard()
      expect(loading.value).toBe(false)
    })

    it('has no error initially', () => {
      const { error } = useAdminDashboard()
      expect(error.value).toBeNull()
    })
  })

  describe('loadStats', () => {
    it('loads stats and populates computed properties', async () => {
      vi.mocked(adminApi.getStats).mockResolvedValue({ data: mockStats })

      const { loadStats, stats, userStats, projectStats, stigStats, srgStats, componentStats, recentActivity } = useAdminDashboard()

      await loadStats()

      expect(stats.value).toEqual(mockStats)
      expect(userStats.value).toEqual(mockStats.users)
      expect(projectStats.value).toEqual(mockStats.projects)
      expect(stigStats.value).toEqual(mockStats.stigs)
      expect(srgStats.value).toEqual(mockStats.srgs)
      expect(componentStats.value).toEqual(mockStats.components)
      expect(recentActivity.value).toEqual(mockStats.recent_activity)
    })

    it('sets loading state', async () => {
      let resolvePromise: (value: { data: typeof mockStats }) => void
      vi.mocked(adminApi.getStats).mockReturnValue(
        new Promise((resolve) => { resolvePromise = resolve }),
      )

      const { loadStats, loading } = useAdminDashboard()
      const promise = loadStats()

      expect(loading.value).toBe(true)

      resolvePromise!({ data: mockStats })
      await promise

      expect(loading.value).toBe(false)
    })

    it('sets error on failure', async () => {
      vi.mocked(adminApi.getStats).mockRejectedValue(new Error('Failed'))

      const { loadStats, error } = useAdminDashboard()

      await loadStats()

      expect(error.value).toBe('Failed')
    })
  })

  describe('totalBenchmarks', () => {
    it('computes total of stigs and srgs', async () => {
      vi.mocked(adminApi.getStats).mockResolvedValue({ data: mockStats })

      const { loadStats, totalBenchmarks } = useAdminDashboard()

      expect(totalBenchmarks.value).toBe(0) // Before loading

      await loadStats()

      expect(totalBenchmarks.value).toBe(12) // 8 stigs + 4 srgs
    })
  })

  describe('timeAgo', () => {
    it('formats just now', () => {
      const { timeAgo } = useAdminDashboard()
      const now = new Date().toISOString()

      expect(timeAgo(now)).toBe('just now')
    })

    it('formats minutes ago', () => {
      const { timeAgo } = useAdminDashboard()
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString()

      expect(timeAgo(fiveMinAgo)).toBe('5 min ago')
    })

    it('formats hours ago', () => {
      const { timeAgo } = useAdminDashboard()
      const twoHoursAgo = new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString()

      expect(timeAgo(twoHoursAgo)).toBe('2 hours ago')
    })

    it('formats days ago', () => {
      const { timeAgo } = useAdminDashboard()
      const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000).toISOString()

      expect(timeAgo(threeDaysAgo)).toBe('3 days ago')
    })
  })

  describe('refresh', () => {
    it('clears and reloads stats', async () => {
      vi.mocked(adminApi.getStats).mockResolvedValue({ data: mockStats })

      const { loadStats, refresh, stats } = useAdminDashboard()

      await loadStats()
      expect(stats.value).not.toBeNull()

      // Modify mock for refresh
      const updatedStats = { ...mockStats, users: { ...mockStats.users, total: 20 } }
      vi.mocked(adminApi.getStats).mockResolvedValue({ data: updatedStats })

      await refresh()

      expect(stats.value?.users.total).toBe(20)
      expect(adminApi.getStats).toHaveBeenCalledTimes(2)
    })
  })
})
