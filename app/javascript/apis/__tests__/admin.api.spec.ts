/**
 * Admin API Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { http } from '@/services/http.service'

import { adminApi, getSettings, getStats } from '../admin.api'

// Mock http service
vi.mock('@/services/http.service', () => ({
  http: {
    get: vi.fn(),
  },
}))

describe('admin API', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getStats', () => {
    it('fetches stats from /admin/stats', async () => {
      const mockStats = {
        users: { total: 10, local: 8, external: 2, admins: 2, locked: 0 },
        projects: { total: 5, recent: 2 },
        components: { total: 15, released: 3 },
        stigs: { total: 8 },
        srgs: { total: 4 },
        recent_activity: [],
      }

      vi.mocked(http.get).mockResolvedValue(mockStats)

      const result = await getStats()

      expect(http.get).toHaveBeenCalledWith('/admin/stats')
      expect(result).toEqual(mockStats)
    })

    it('throws on API error', async () => {
      vi.mocked(http.get).mockRejectedValue(new Error('Unauthorized'))

      await expect(getStats()).rejects.toThrow('Unauthorized')
    })
  })

  describe('getSettings', () => {
    it('fetches settings from /admin/settings', async () => {
      const mockSettings = {
        authentication: {
          local_login: { enabled: true, email_confirmation: false, session_timeout_minutes: 60 },
          user_registration: { enabled: true },
          lockable: { enabled: true, max_attempts: 5, unlock_in_minutes: 30 },
        },
        ldap: { enabled: false, title: '' },
        oidc: { enabled: true, title: 'SSO Login', issuer: 'https://example.com' },
        smtp: { enabled: true, address: 'smtp.example.com', port: 587 },
        slack: { enabled: false },
        project: { create_permission_enabled: false },
        app: { url: 'https://vulcan.example.com', contact_email: 'admin@example.com' },
      }

      vi.mocked(http.get).mockResolvedValue(mockSettings)

      const result = await getSettings()

      expect(http.get).toHaveBeenCalledWith('/admin/settings')
      expect(result).toEqual(mockSettings)
    })

    it('throws on API error', async () => {
      vi.mocked(http.get).mockRejectedValue(new Error('Forbidden'))

      await expect(getSettings()).rejects.toThrow('Forbidden')
    })
  })

  describe('adminApi object', () => {
    it('exports all functions', () => {
      expect(adminApi.getStats).toBe(getStats)
      expect(adminApi.getSettings).toBe(getSettings)
    })
  })
})
