/**
 * useAuth Composable Unit Tests
 */

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
    store = useAuthStore()
    composable = useAuth()
    mockLocation.href = ''
  })

  describe('reactive state', () => {
    it('exposes user as reactive ref', () => {
      expect(composable.user.value).toBeNull()

      store.$patch({ user: { id: 1, email: 'test@test.com' } as any })
      expect(composable.user.value).toEqual({ id: 1, email: 'test@test.com' })
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

      store.$patch({ user: { id: 1, admin: true } as any })
      // Need to get fresh composable to see updated getter
      const fresh = useAuth()
      expect(fresh.isAdmin).toBe(true)
    })

    it('userEmail reflects store getter', () => {
      expect(composable.userEmail).toBe('')

      store.$patch({ user: { id: 1, email: 'test@example.com' } as any })
      const fresh = useAuth()
      expect(fresh.userEmail).toBe('test@example.com')
    })

    it('userName reflects store getter', () => {
      expect(composable.userName).toBe('')

      store.$patch({ user: { id: 1, name: 'John Doe' } as any })
      const fresh = useAuth()
      expect(fresh.userName).toBe('John Doe')
    })
  })
})
