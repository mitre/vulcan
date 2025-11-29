/**
 * Users Store Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useUsersStore } from '../users.store'

// Mock the API module
vi.mock('@/apis/users.api', () => ({
  getUsers: vi.fn(),
  updateUser: vi.fn(),
  deleteUser: vi.fn(),
}))

describe('users Store', () => {
  let store: ReturnType<typeof useUsersStore>

  beforeEach(() => {
    store = useUsersStore()
  })

  describe('initial state', () => {
    it('has empty users array', () => {
      expect(store.users).toEqual([])
    })

    it('has empty histories array', () => {
      expect(store.histories).toEqual([])
    })

    it('has loading false', () => {
      expect(store.loading).toBe(false)
    })

    it('has error null', () => {
      expect(store.error).toBeNull()
    })
  })

  describe('getters', () => {
    it('userCount returns users length', () => {
      expect(store.userCount).toBe(0)
      store.$patch({ users: [{ id: 1 }, { id: 2 }] as any })
      expect(store.userCount).toBe(2)
    })

    it('adminCount returns count of admin users', () => {
      store.$patch({
        users: [
          { id: 1, admin: true },
          { id: 2, admin: false },
          { id: 3, admin: true },
        ] as any,
      })
      expect(store.adminCount).toBe(2)
    })

    it('getUserById finds user by id', () => {
      const mockUser = { id: 42, name: 'Test User' }
      store.$patch({ users: [mockUser] as any })
      expect(store.getUserById(42)).toEqual(mockUser)
      expect(store.getUserById(999)).toBeUndefined()
    })
  })

  describe('actions', () => {
    it('reset clears all state', () => {
      store.$patch({
        users: [{ id: 1 }] as any,
        histories: [{ id: 1 }] as any,
        loading: true,
        error: 'some error',
      })

      store.reset()

      expect(store.users).toEqual([])
      expect(store.histories).toEqual([])
      expect(store.loading).toBe(false)
      expect(store.error).toBeNull()
    })
  })
})
