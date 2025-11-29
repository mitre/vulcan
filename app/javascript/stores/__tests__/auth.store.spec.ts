/**
 * Auth Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useAuthStore } from '../auth.store'

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

describe('auth Store', () => {
  let store: ReturnType<typeof useAuthStore>

  beforeEach(() => {
    store = useAuthStore()
    mockLocation.href = ''
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
})
