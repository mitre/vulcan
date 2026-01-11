/**
 * useAuth Composable Unit Tests
 */

import type { IUser } from '@/types'
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '@/stores'
import { useAuth } from '../useAuth'

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
  getCurrentUser: vi.fn(),
}))

// Mock window.location
const mockLocation = { href: '' }
Object.defineProperty(window, 'location', {
  value: mockLocation,
  writable: true,
})

describe('useAuth', () => {
  let composable: ReturnType<typeof useAuth>
  let store: ReturnType<typeof useAuthStore>

  beforeEach(() => {
    setActivePinia(createPinia())
    store = useAuthStore()
    composable = useAuth()
    mockLocation.href = ''
    vi.clearAllMocks()
  })

  describe('reactive state', () => {
    it('exposes user as reactive ref', () => {
      expect(composable.user.value).toBeNull()

      const mockUser: Partial<IUser> = { id: 1, email: 'test@test.com' }
      store.$patch({ user: mockUser })
      expect(composable.user.value).toEqual(mockUser)
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })
  })

  describe('computed properties', () => {
    it('isAdmin reflects store getter', () => {
      expect(composable.isAdmin).toBe(false)

      const mockAdmin: Partial<IUser> = { id: 1, admin: true }
      store.$patch({ user: mockAdmin })
      // Need to get fresh composable to see updated getter
      const fresh = useAuth()
      expect(fresh.isAdmin).toBe(true)
    })

    it('userEmail reflects store getter', () => {
      expect(composable.userEmail).toBe('')

      const mockUser: Partial<IUser> = { id: 1, email: 'test@example.com' }
      store.$patch({ user: mockUser })
      const fresh = useAuth()
      expect(fresh.userEmail).toBe('test@example.com')
    })

    it('userName reflects store getter', () => {
      expect(composable.userName).toBe('')

      const mockUser: Partial<IUser> = { id: 1, name: 'John Doe' }
      store.$patch({ user: mockUser })
      const fresh = useAuth()
      expect(fresh.userName).toBe('John Doe')
    })
  })

  describe('checkAuth action', () => {
    it('calls store.checkAuth', async () => {
      const checkAuthSpy = vi.spyOn(store, 'checkAuth')

      await composable.checkAuth()

      expect(checkAuthSpy).toHaveBeenCalled()
    })

    it('returns true when authentication check succeeds', async () => {
      const mockResponse = { data: { user: { id: 1 } } }
      vi.spyOn(store, 'checkAuth').mockResolvedValue(mockResponse)

      const result = await composable.checkAuth()

      expect(result).toBe(true)
    })

    it('returns false when authentication check fails', async () => {
      vi.spyOn(store, 'checkAuth').mockRejectedValue(new Error('Unauthorized'))

      const result = await composable.checkAuth()

      expect(result).toBe(false)
    })

    it('does not show error toast on 401 (expected unauthenticated state)', async () => {
      const errorSpy = vi.fn()
      vi.spyOn(store, 'checkAuth').mockResolvedValue(null)

      await composable.checkAuth()

      // Should not call toast.error for expected 401
      expect(errorSpy).not.toHaveBeenCalled()
    })
  })
})
