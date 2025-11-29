/**
 * useUsers Composable Unit Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { useUsersStore } from '@/stores'
import { useUsers } from '../useUsers'

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
vi.mock('@/apis/users.api', () => ({
  getUsers: vi.fn(),
  updateUser: vi.fn(),
  deleteUser: vi.fn(),
}))

describe('useUsers', () => {
  let composable: ReturnType<typeof useUsers>
  let store: ReturnType<typeof useUsersStore>

  beforeEach(() => {
    store = useUsersStore()
    composable = useUsers()
  })

  describe('reactive state', () => {
    it('exposes users as reactive ref', () => {
      expect(composable.users.value).toEqual([])

      store.$patch({ users: [{ id: 1, name: 'Test' }] as any })
      expect(composable.users.value).toHaveLength(1)
    })

    it('exposes histories as reactive ref', () => {
      expect(composable.histories.value).toEqual([])

      store.$patch({ histories: [{ id: 1 }] as any })
      expect(composable.histories.value).toHaveLength(1)
    })

    it('exposes loading as reactive ref', () => {
      expect(composable.loading.value).toBe(false)

      store.$patch({ loading: true })
      expect(composable.loading.value).toBe(true)
    })

    it('exposes error as reactive ref', () => {
      expect(composable.error.value).toBeNull()

      store.$patch({ error: 'Test error' })
      expect(composable.error.value).toBe('Test error')
    })
  })

  describe('computed properties', () => {
    it('count returns users length', () => {
      expect(composable.count.value).toBe(0)

      store.$patch({ users: [{ id: 1 }, { id: 2 }, { id: 3 }] as any })
      expect(composable.count.value).toBe(3)
    })
  })
})
