/**
 * Auth Store Unit Tests
 *
 * Tests the auth store with modern /api/auth/* endpoints
 */

import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import * as authApi from '@/apis/auth.api'
import { useAuthStore } from '../auth.store'

// Mock the API module
vi.mock('@/apis/auth.api', () => ({
  login: vi.fn(),
  logout: vi.fn(),
  register: vi.fn(),
  getCurrentUser: vi.fn(),
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

describe('auth Store', () => {
  let store: ReturnType<typeof useAuthStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useAuthStore()
    mockLocation.href = ''
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('has null user by default', () => {
      expect(store.user).toBeNull()
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })
  })

  describe('getters', () => {
    it('signedIn returns false when no user', () => {
      expect(store.signedIn).toBe(false)
    })

    it('signedIn returns true when user exists', () => {
      store.$patch({ user: { id: 1, email: 'test@test.com' } as any })
      expect(store.signedIn).toBe(true)
    })

    it('isAdmin returns false when no user', () => {
      expect(store.isAdmin).toBe(false)
    })

    it('isAdmin returns true when user is admin', () => {
      store.$patch({ user: { id: 1, admin: true } as any })
      expect(store.isAdmin).toBe(true)
    })

    it('userEmail returns empty string when no user', () => {
      expect(store.userEmail).toBe('')
    })

    it('userEmail returns email when user exists', () => {
      store.$patch({ user: { id: 1, email: 'test@example.com' } as any })
      expect(store.userEmail).toBe('test@example.com')
    })

    it('userName returns empty string when no user', () => {
      expect(store.userName).toBe('')
    })

    it('userName returns name when user exists', () => {
      store.$patch({ user: { id: 1, name: 'Test User' } as any })
      expect(store.userName).toBe('Test User')
    })

    it('userId returns undefined when no user', () => {
      expect(store.userId).toBeUndefined()
    })

    it('userId returns id when user exists', () => {
      store.$patch({ user: { id: 42 } as any })
      expect(store.userId).toBe(42)
    })
  })

  describe('actions', () => {
    it('setUser updates user', () => {
      const mockUser = { id: 1, email: 'test@test.com', name: 'Test' } as any
      store.setUser(mockUser)
      expect(store.user).toEqual(mockUser)
    })

    it('clearUser sets user to null', () => {
      store.$patch({ user: { id: 1 } as any })
      store.clearUser()
      expect(store.user).toBeNull()
    })

    it('reset clears all state', () => {
      store.$patch({ user: { id: 1 } as any, loading: true })
      store.reset()
      expect(store.user).toBeNull()
      expect(store.loading).toBe(false)
    })
  })

  describe('login action', () => {
    const mockUser = { id: 1, email: 'test@example.com', admin: false, name: 'Test User' }

    it('calls login API and sets user from response.data.user', async () => {
      vi.mocked(authApi.login).mockResolvedValue({
        data: { user: mockUser },
        status: 200,
      } as any)

      await store.login({ email: 'test@example.com', password: 'password123' })

      expect(authApi.login).toHaveBeenCalledWith('test@example.com', 'password123')
      expect(store.user).toEqual(mockUser)
    })

    it('sets loading to true during API call', async () => {
      vi.mocked(authApi.login).mockImplementation(() => {
        expect(store.loading).toBe(true)
        return Promise.resolve({ data: { user: mockUser }, status: 200 } as any)
      })

      await store.login({ email: 'test@example.com', password: 'password123' })
      expect(store.loading).toBe(false)
    })

    it('sets error message when login fails', async () => {
      const errorMessage = 'Invalid credentials'
      vi.mocked(authApi.login).mockRejectedValue(new Error(errorMessage))

      try {
        await store.login({ email: 'test@example.com', password: 'wrong' })
      }
      catch {
        // Expected to throw
      }

      expect(store.error).toBe('Invalid credentials')
      expect(store.user).toBeNull()
    })

    it('preserves user data structure from API', async () => {
      const adminUser = { id: 2, email: 'admin@example.com', admin: true, name: 'Admin User' }
      vi.mocked(authApi.login).mockResolvedValue({
        data: { user: adminUser },
        status: 200,
      } as any)

      await store.login({ email: 'admin@example.com', password: 'password' })

      expect(store.user).toEqual(adminUser)
      expect(store.isAdmin).toBe(true)
    })
  })

  describe('logout action', () => {
    beforeEach(() => {
      store.$patch({ user: { id: 1, email: 'test@example.com' } as any })
    })

    it('calls logout API', async () => {
      vi.mocked(authApi.logout).mockResolvedValue({ status: 204, data: '' } as any)

      await store.logout()

      expect(authApi.logout).toHaveBeenCalled()
    })

    it('clears user after logout', async () => {
      vi.mocked(authApi.logout).mockResolvedValue({ status: 204, data: '' } as any)

      await store.logout()

      expect(store.user).toBeNull()
    })

    it('redirects to login page after logout', async () => {
      vi.mocked(authApi.logout).mockResolvedValue({ status: 204, data: '' } as any)

      await store.logout()

      expect(mockLocation.href).toBe('/users/sign_in')
    })

    it('clears user even if API call fails', async () => {
      vi.mocked(authApi.logout).mockRejectedValue(new Error('Network error'))

      await store.logout()

      expect(store.user).toBeNull()
      expect(mockLocation.href).toBe('/users/sign_in')
    })
  })

  describe('checkAuth action', () => {
    const mockUser = { id: 1, email: 'test@example.com', admin: false, name: 'Test User' }

    it('calls getCurrentUser API', async () => {
      vi.mocked(authApi.getCurrentUser).mockResolvedValue({
        data: { user: mockUser },
        status: 200,
      } as any)

      await store.checkAuth()

      expect(authApi.getCurrentUser).toHaveBeenCalled()
    })

    it('sets user from API response', async () => {
      vi.mocked(authApi.getCurrentUser).mockResolvedValue({
        data: { user: mockUser },
        status: 200,
      } as any)

      await store.checkAuth()

      expect(store.user).toEqual(mockUser)
    })

    it('handles 401 unauthorized by clearing user', async () => {
      vi.mocked(authApi.getCurrentUser).mockRejectedValue({
        response: { status: 401 },
      })

      await store.checkAuth()

      expect(store.user).toBeNull()
    })

    it('sets loading state during API call', async () => {
      vi.mocked(authApi.getCurrentUser).mockImplementation(() => {
        expect(store.loading).toBe(true)
        return Promise.resolve({ data: { user: mockUser }, status: 200 } as any)
      })

      await store.checkAuth()
      expect(store.loading).toBe(false)
    })
  })

  describe('register action', () => {
    it('calls register API with user data', async () => {
      const userData = {
        name: 'New User',
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
      }
      vi.mocked(authApi.register).mockResolvedValue({ status: 201, data: {} } as any)

      await store.register(userData)

      expect(authApi.register).toHaveBeenCalledWith(
        'New User',
        'new@example.com',
        'password123',
        'password123',
        undefined,
      )
    })

    it('includes slack_user_id when provided', async () => {
      const userData = {
        name: 'New User',
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        slack_user_id: 'U12345',
      }
      vi.mocked(authApi.register).mockResolvedValue({ status: 201, data: {} } as any)

      await store.register(userData)

      expect(authApi.register).toHaveBeenCalledWith(
        'New User',
        'new@example.com',
        'password123',
        'password123',
        'U12345',
      )
    })
  })
})
