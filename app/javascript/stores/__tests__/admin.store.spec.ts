/**
 * Admin Store Tests
 */

import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { adminApi } from '@/apis/admin.api'

import { useAdminStore } from '../admin.store'

// Mock admin API
vi.mock('@/apis/admin.api', () => ({
  adminApi: {
    getStats: vi.fn(),
    getSettings: vi.fn(),
  },
}))

describe('admin Store', () => {
  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('has null stats and settings', () => {
      const store = useAdminStore()

      expect(store.stats).toBeNull()
      expect(store.settings).toBeNull()
      expect(store.statsLoading).toBe(false)
      expect(store.settingsLoading).toBe(false)
      expect(store.statsError).toBeNull()
      expect(store.settingsError).toBeNull()
    })
  })

  describe('fetchStats', () => {
    const mockStats = {
      users: { total: 10, local: 8, external: 2, admins: 2, locked: 0 },
      projects: { total: 5, recent: 2 },
      components: { total: 15, released: 3 },
      stigs: { total: 8 },
      srgs: { total: 4 },
      recent_activity: [
        { id: 1, action: 'create', auditable_type: 'Component', auditable_name: 'Test', user_name: 'Admin', created_at: '2024-01-01' },
      ],
    }

    it('fetches and stores stats', async () => {
      vi.mocked(adminApi.getStats).mockResolvedValue({ data: mockStats })
      const store = useAdminStore()

      await store.fetchStats()

      expect(adminApi.getStats).toHaveBeenCalled()
      expect(store.stats).toEqual(mockStats)
      expect(store.statsLoading).toBe(false)
      expect(store.statsError).toBeNull()
    })

    it('sets loading state during fetch', async () => {
      let resolvePromise: (value: { data: typeof mockStats }) => void
      vi.mocked(adminApi.getStats).mockReturnValue(
        new Promise((resolve) => { resolvePromise = resolve }),
      )

      const store = useAdminStore()
      const fetchPromise = store.fetchStats()

      expect(store.statsLoading).toBe(true)

      resolvePromise!({ data: mockStats })
      await fetchPromise

      expect(store.statsLoading).toBe(false)
    })

    it('sets error on failure', async () => {
      vi.mocked(adminApi.getStats).mockRejectedValue(new Error('Network error'))
      const store = useAdminStore()

      await expect(store.fetchStats()).rejects.toThrow('Network error')

      expect(store.statsError).toBe('Network error')
      expect(store.stats).toBeNull()
      expect(store.statsLoading).toBe(false)
    })
  })

  describe('fetchSettings', () => {
    const mockSettings = {
      authentication: {
        local_login: { enabled: true, email_confirmation: false, session_timeout_minutes: 60 },
        user_registration: { enabled: true },
        lockable: { enabled: true, max_attempts: 5, unlock_in_minutes: 30 },
      },
      ldap: { enabled: false, title: '' },
      oidc: { enabled: true, title: 'SSO', issuer: 'https://example.com' },
      smtp: { enabled: true, address: 'smtp.example.com', port: 587 },
      slack: { enabled: false },
      project: { create_permission_enabled: false },
      app: { url: 'https://vulcan.example.com', contact_email: 'admin@example.com' },
    }

    it('fetches and stores settings', async () => {
      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: mockSettings })
      const store = useAdminStore()

      await store.fetchSettings()

      expect(adminApi.getSettings).toHaveBeenCalled()
      expect(store.settings).toEqual(mockSettings)
      expect(store.settingsLoading).toBe(false)
      expect(store.settingsError).toBeNull()
    })

    it('sets loading state during fetch', async () => {
      let resolvePromise: (value: { data: typeof mockSettings }) => void
      vi.mocked(adminApi.getSettings).mockReturnValue(
        new Promise((resolve) => { resolvePromise = resolve }),
      )

      const store = useAdminStore()
      const fetchPromise = store.fetchSettings()

      expect(store.settingsLoading).toBe(true)

      resolvePromise!({ data: mockSettings })
      await fetchPromise

      expect(store.settingsLoading).toBe(false)
    })

    it('sets error on failure', async () => {
      vi.mocked(adminApi.getSettings).mockRejectedValue(new Error('Forbidden'))
      const store = useAdminStore()

      await expect(store.fetchSettings()).rejects.toThrow('Forbidden')

      expect(store.settingsError).toBe('Forbidden')
      expect(store.settings).toBeNull()
      expect(store.settingsLoading).toBe(false)
    })
  })

  describe('clearStats', () => {
    it('clears stats and error', async () => {
      const mockStats = {
        users: { total: 10, local: 8, external: 2, admins: 2, locked: 0 },
        projects: { total: 5, recent: 2 },
        components: { total: 15, released: 3 },
        stigs: { total: 8 },
        srgs: { total: 4 },
        recent_activity: [],
      }

      vi.mocked(adminApi.getStats).mockResolvedValue({ data: mockStats })
      const store = useAdminStore()

      await store.fetchStats()
      expect(store.stats).not.toBeNull()

      store.clearStats()

      expect(store.stats).toBeNull()
      expect(store.statsError).toBeNull()
    })
  })

  describe('clearSettings', () => {
    it('clears settings and error', async () => {
      const mockSettings = {
        authentication: {
          local_login: { enabled: true, email_confirmation: false, session_timeout_minutes: 60 },
          user_registration: { enabled: true },
          lockable: { enabled: true, max_attempts: 5, unlock_in_minutes: 30 },
        },
        ldap: { enabled: false, title: '' },
        oidc: { enabled: false, title: '', issuer: '' },
        smtp: { enabled: false, address: '', port: 0 },
        slack: { enabled: false },
        project: { create_permission_enabled: false },
        app: { url: '', contact_email: '' },
      }

      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: mockSettings })
      const store = useAdminStore()

      await store.fetchSettings()
      expect(store.settings).not.toBeNull()

      store.clearSettings()

      expect(store.settings).toBeNull()
      expect(store.settingsError).toBeNull()
    })
  })
})
