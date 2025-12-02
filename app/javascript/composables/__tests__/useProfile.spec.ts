/**
 * useProfile Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '@/stores'
import { useProfile } from '../useProfile'

// Mock the toast composable
vi.mock('../useToast', () => ({
  useAppToast: () => ({
    success: vi.fn(),
    error: vi.fn(),
    info: vi.fn(),
    warning: vi.fn(),
  }),
}))

// Mock the API module
vi.mock('@/apis/auth.api', () => ({
  login: vi.fn(),
  logout: vi.fn(),
  register: vi.fn(),
  getProfile: vi.fn(),
  updateProfile: vi.fn(),
  deleteAccount: vi.fn(),
}))

// Mock window.location
const mockLocation = { href: '' }
Object.defineProperty(window, 'location', {
  value: mockLocation,
  writable: true,
})

describe('useProfile', () => {
  let composable: ReturnType<typeof useProfile>
  let store: ReturnType<typeof useAuthStore>

  beforeEach(() => {
    store = useAuthStore()
    composable = useProfile()
    mockLocation.href = ''
  })

  describe('reactive state', () => {
    it('exposes user as reactive ref', () => {
      expect(composable.user.value).toBeNull()

      store.$patch({ user: { id: 1, email: 'test@test.com', name: 'Test User' } as any })
      expect(composable.user.value).toEqual({ id: 1, email: 'test@test.com', name: 'Test User' })
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })
  })

  describe('computed properties', () => {
    it('name returns user name', () => {
      expect(composable.name.value).toBe('')

      store.$patch({ user: { id: 1, name: 'John Doe' } as any })
      expect(composable.name.value).toBe('John Doe')
    })

    it('email returns user email', () => {
      expect(composable.email.value).toBe('')

      store.$patch({ user: { id: 1, email: 'test@example.com' } as any })
      expect(composable.email.value).toBe('test@example.com')
    })

    it('slackUserId returns slack user id', () => {
      expect(composable.slackUserId.value).toBe('')

      store.$patch({ user: { id: 1, slack_user_id: 'U123456' } as any })
      expect(composable.slackUserId.value).toBe('U123456')
    })

    it('isOAuthUser returns false for local users', () => {
      store.$patch({ user: { id: 1, email: 'test@test.com' } as any })
      expect(composable.isOAuthUser.value).toBe(false)
    })

    it('isOAuthUser returns true for OAuth users', () => {
      store.$patch({ user: { id: 1, email: 'test@test.com', provider: 'github' } as any })
      expect(composable.isOAuthUser.value).toBe(true)
    })

    it('provider returns OAuth provider name', () => {
      expect(composable.provider.value).toBeNull()

      store.$patch({ user: { id: 1, provider: 'okta' } as any })
      expect(composable.provider.value).toBe('okta')
    })
  })

  describe('actions', () => {
    it('refresh delegates to store fetchProfile', async () => {
      const fetchProfileSpy = vi.spyOn(store, 'fetchProfile').mockResolvedValue({ data: {} } as any)

      await composable.refresh()

      expect(fetchProfileSpy).toHaveBeenCalled()
    })

    it('updateProfile delegates to store updateProfile', async () => {
      const updateData = { name: 'New Name', current_password: 'test123' }
      const updateProfileSpy = vi.spyOn(store, 'updateProfile').mockResolvedValue({ data: { success: true } } as any)

      await composable.updateProfile(updateData)

      expect(updateProfileSpy).toHaveBeenCalledWith(updateData)
    })

    it('deleteAccount delegates to store deleteAccount', async () => {
      const deleteAccountSpy = vi.spyOn(store, 'deleteAccount').mockResolvedValue(undefined)

      await composable.deleteAccount()

      expect(deleteAccountSpy).toHaveBeenCalled()
    })
  })
})
