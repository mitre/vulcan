/**
 * useAdminSettings Composable Tests
 */

import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { adminApi } from '@/apis/admin.api'

import { useAdminSettings } from '../useAdminSettings'

// Mock admin API
vi.mock('@/apis/admin.api', () => ({
  adminApi: {
    getStats: vi.fn(),
    getSettings: vi.fn(),
  },
}))

describe('useAdminSettings', () => {
  const mockSettings = {
    authentication: {
      local_login: { enabled: true, email_confirmation: true, session_timeout_minutes: 60 },
      user_registration: { enabled: false },
      lockable: { enabled: true, max_attempts: 5, unlock_in_minutes: 30 },
    },
    ldap: { enabled: true, title: 'LDAP Login' },
    oidc: { enabled: true, title: 'SSO Login', issuer: 'https://sso.example.com' },
    smtp: { enabled: true, address: 'smtp.example.com', port: 587 },
    slack: { enabled: false },
    project: { create_permission_enabled: true },
    app: { url: 'https://vulcan.example.com', contact_email: 'admin@example.com' },
  }

  beforeEach(() => {
    setActivePinia(createPinia())
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('has null settings', () => {
      const { settings, authentication, ldap, oidc, smtp, slack, project, app } = useAdminSettings()

      expect(settings.value).toBeNull()
      expect(authentication.value).toBeNull()
      expect(ldap.value).toBeNull()
      expect(oidc.value).toBeNull()
      expect(smtp.value).toBeNull()
      expect(slack.value).toBeNull()
      expect(project.value).toBeNull()
      expect(app.value).toBeNull()
    })

    it('has loading false initially', () => {
      const { loading } = useAdminSettings()
      expect(loading.value).toBe(false)
    })

    it('has no error initially', () => {
      const { error } = useAdminSettings()
      expect(error.value).toBeNull()
    })

    it('has false for all enabled flags initially', () => {
      const { isLocalLoginEnabled, isLdapEnabled, isOidcEnabled, isSmtpEnabled, isSlackEnabled } = useAdminSettings()

      expect(isLocalLoginEnabled.value).toBe(false)
      expect(isLdapEnabled.value).toBe(false)
      expect(isOidcEnabled.value).toBe(false)
      expect(isSmtpEnabled.value).toBe(false)
      expect(isSlackEnabled.value).toBe(false)
    })
  })

  describe('loadSettings', () => {
    it('loads settings and populates computed properties', async () => {
      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: mockSettings })

      const { loadSettings, settings, authentication, ldap, oidc, smtp, slack, project, app } = useAdminSettings()

      await loadSettings()

      expect(settings.value).toEqual(mockSettings)
      expect(authentication.value).toEqual(mockSettings.authentication)
      expect(ldap.value).toEqual(mockSettings.ldap)
      expect(oidc.value).toEqual(mockSettings.oidc)
      expect(smtp.value).toEqual(mockSettings.smtp)
      expect(slack.value).toEqual(mockSettings.slack)
      expect(project.value).toEqual(mockSettings.project)
      expect(app.value).toEqual(mockSettings.app)
    })

    it('sets enabled flags correctly', async () => {
      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: mockSettings })

      const { loadSettings, isLocalLoginEnabled, isLdapEnabled, isOidcEnabled, isSmtpEnabled, isSlackEnabled } = useAdminSettings()

      await loadSettings()

      expect(isLocalLoginEnabled.value).toBe(true)
      expect(isLdapEnabled.value).toBe(true)
      expect(isOidcEnabled.value).toBe(true)
      expect(isSmtpEnabled.value).toBe(true)
      expect(isSlackEnabled.value).toBe(false) // Slack is disabled in mock
    })

    it('sets loading state', async () => {
      let resolvePromise: (value: { data: typeof mockSettings }) => void
      vi.mocked(adminApi.getSettings).mockReturnValue(
        new Promise((resolve) => { resolvePromise = resolve }),
      )

      const { loadSettings, loading } = useAdminSettings()
      const promise = loadSettings()

      expect(loading.value).toBe(true)

      resolvePromise!({ data: mockSettings })
      await promise

      expect(loading.value).toBe(false)
    })

    it('sets error on failure', async () => {
      vi.mocked(adminApi.getSettings).mockRejectedValue(new Error('Forbidden'))

      const { loadSettings, error } = useAdminSettings()

      await loadSettings()

      expect(error.value).toBe('Forbidden')
    })
  })

  describe('refresh', () => {
    it('clears and reloads settings', async () => {
      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: mockSettings })

      const { loadSettings, refresh, settings } = useAdminSettings()

      await loadSettings()
      expect(settings.value).not.toBeNull()

      // Modify mock for refresh
      const updatedSettings = {
        ...mockSettings,
        slack: { enabled: true },
      }
      vi.mocked(adminApi.getSettings).mockResolvedValue({ data: updatedSettings })

      await refresh()

      expect(settings.value?.slack.enabled).toBe(true)
      expect(adminApi.getSettings).toHaveBeenCalledTimes(2)
    })
  })
})
