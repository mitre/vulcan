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
  getAdminUsers: vi.fn(),
  lockUser: vi.fn(),
  unlockUser: vi.fn(),
  resetUserPassword: vi.fn(),
  resendUserConfirmation: vi.fn(),
  inviteUser: vi.fn(),
  updateAdminUser: vi.fn(),
  deleteAdminUser: vi.fn(),
}))

describe('useUsers', () => {
  let composable: ReturnType<typeof useUsers>
  let store: ReturnType<typeof useUsersStore>

  beforeEach(() => {
    store = useUsersStore()
    store.reset()
    composable = useUsers()
  })

  describe('reactive state', () => {
    it('exposes users as reactive ref', () => {
      expect(composable.users.value).toEqual([])

      store.$patch({ users: [{ id: 1, name: 'Test' }] as any })
      expect(composable.users.value).toHaveLength(1)
    })

    it('exposes pagination as reactive ref', () => {
      expect(composable.pagination.value).toBeNull()

      store.$patch({ pagination: { page: 1, per_page: 25, total: 100, total_pages: 4 } })
      expect(composable.pagination.value).toEqual({ page: 1, per_page: 25, total: 100, total_pages: 4 })
    })

    it('exposes filters as reactive ref', () => {
      expect(composable.filters.value).toEqual({
        search: '',
        provider: 'all',
        role: 'all',
        status: 'all',
      })

      store.$patch({ filters: { search: 'test', provider: 'local', role: 'admin', status: 'active' } })
      expect(composable.filters.value.search).toBe('test')
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
    it('userCount returns pagination total or users length', () => {
      expect(composable.userCount.value).toBe(0)

      store.$patch({ users: [{ id: 1 }, { id: 2 }, { id: 3 }] as any })
      expect(composable.userCount.value).toBe(3)

      store.$patch({ pagination: { page: 1, per_page: 25, total: 100, total_pages: 4 } })
      expect(composable.userCount.value).toBe(100)
    })

    it('adminCount returns admin users count', () => {
      expect(composable.adminCount.value).toBe(0)

      store.$patch({ users: [{ id: 1, admin: true }, { id: 2, admin: false }, { id: 3, admin: true }] as any })
      expect(composable.adminCount.value).toBe(2)
    })

    it('lockedCount returns locked users count', () => {
      expect(composable.lockedCount.value).toBe(0)

      store.$patch({ users: [{ id: 1, locked: true }, { id: 2, locked: false }, { id: 3, locked: true }] as any })
      expect(composable.lockedCount.value).toBe(2)
    })

    it('currentPage returns pagination page or 1', () => {
      expect(composable.currentPage.value).toBe(1)

      store.$patch({ pagination: { page: 3, per_page: 25, total: 100, total_pages: 4 } })
      expect(composable.currentPage.value).toBe(3)
    })

    it('totalPages returns pagination total_pages or 1', () => {
      expect(composable.totalPages.value).toBe(1)

      store.$patch({ pagination: { page: 1, per_page: 25, total: 100, total_pages: 4 } })
      expect(composable.totalPages.value).toBe(4)
    })

    it('hasActiveFilters returns true when search filter is set', () => {
      // Reset filters first
      store.$patch({ filters: { search: '', provider: 'all', role: 'all', status: 'all' } })
      expect(composable.hasActiveFilters.value).toBe(false)

      store.$patch({ filters: { search: 'test', provider: 'all', role: 'all', status: 'all' } })
      expect(composable.hasActiveFilters.value).toBe(true)
    })
  })

  describe('actions', () => {
    it('fetchUsers calls store.fetchAdminUsers', async () => {
      const spy = vi.spyOn(store, 'fetchAdminUsers').mockResolvedValue(undefined as any)
      await composable.fetchUsers(2)
      expect(spy).toHaveBeenCalledWith(2)
    })

    it('setFilters calls store.setFilters', async () => {
      const spy = vi.spyOn(store, 'setFilters').mockResolvedValue(undefined as any)
      await composable.setFilters({ search: 'test' })
      expect(spy).toHaveBeenCalledWith({ search: 'test' })
    })

    it('clearFilters calls store.clearFilters', async () => {
      const spy = vi.spyOn(store, 'clearFilters').mockResolvedValue(undefined as any)
      await composable.clearFilters()
      expect(spy).toHaveBeenCalled()
    })

    it('goToPage calls store.goToPage', async () => {
      const spy = vi.spyOn(store, 'goToPage').mockResolvedValue(undefined as any)
      await composable.goToPage(3)
      expect(spy).toHaveBeenCalledWith(3)
    })

    it('lockUser calls store.lockUser and returns true on success', async () => {
      const spy = vi.spyOn(store, 'lockUser').mockResolvedValue({ toast: 'User locked' })
      const result = await composable.lockUser(1)
      expect(spy).toHaveBeenCalledWith(1)
      expect(result).toBe(true)
    })

    it('lockUser returns false on error', async () => {
      vi.spyOn(store, 'lockUser').mockRejectedValue(new Error('Lock failed'))
      const result = await composable.lockUser(1)
      expect(result).toBe(false)
    })

    it('unlockUser calls store.unlockUser and returns true on success', async () => {
      const spy = vi.spyOn(store, 'unlockUser').mockResolvedValue({ toast: 'User unlocked' })
      const result = await composable.unlockUser(1)
      expect(spy).toHaveBeenCalledWith(1)
      expect(result).toBe(true)
    })

    it('unlockUser returns false on error', async () => {
      vi.spyOn(store, 'unlockUser').mockRejectedValue(new Error('Unlock failed'))
      const result = await composable.unlockUser(1)
      expect(result).toBe(false)
    })

    it('resetPassword calls store.resetPassword and returns true on success', async () => {
      const spy = vi.spyOn(store, 'resetPassword').mockResolvedValue({ toast: 'Email sent' })
      const result = await composable.resetPassword(1)
      expect(spy).toHaveBeenCalledWith(1)
      expect(result).toBe(true)
    })

    it('resetPassword returns false on error', async () => {
      vi.spyOn(store, 'resetPassword').mockRejectedValue(new Error('Reset failed'))
      const result = await composable.resetPassword(1)
      expect(result).toBe(false)
    })

    it('resendConfirmation calls store.resendConfirmation and returns true on success', async () => {
      const spy = vi.spyOn(store, 'resendConfirmation').mockResolvedValue({ toast: 'Email sent' })
      const result = await composable.resendConfirmation(1)
      expect(spy).toHaveBeenCalledWith(1)
      expect(result).toBe(true)
    })

    it('resendConfirmation returns false on error', async () => {
      vi.spyOn(store, 'resendConfirmation').mockRejectedValue(new Error('Resend failed'))
      const result = await composable.resendConfirmation(1)
      expect(result).toBe(false)
    })

    it('inviteUser calls store.inviteUser and returns true on success', async () => {
      const spy = vi.spyOn(store, 'inviteUser').mockResolvedValue({ toast: 'Invitation sent' })
      const result = await composable.inviteUser({ email: 'test@example.com', name: 'Test' })
      expect(spy).toHaveBeenCalledWith({ email: 'test@example.com', name: 'Test' })
      expect(result).toBe(true)
    })

    it('inviteUser returns false on error', async () => {
      vi.spyOn(store, 'inviteUser').mockRejectedValue(new Error('Invite failed'))
      const result = await composable.inviteUser({ email: 'test@example.com', name: 'Test' })
      expect(result).toBe(false)
    })

    it('updateUser calls store.updateUser and returns true on success', async () => {
      const spy = vi.spyOn(store, 'updateUser').mockResolvedValue({ toast: 'User updated' })
      const result = await composable.updateUser(1, { name: 'New Name' })
      expect(spy).toHaveBeenCalledWith(1, { name: 'New Name' })
      expect(result).toBe(true)
    })

    it('updateUser returns false on error', async () => {
      vi.spyOn(store, 'updateUser').mockRejectedValue(new Error('Update failed'))
      const result = await composable.updateUser(1, { name: 'New Name' })
      expect(result).toBe(false)
    })

    it('deleteUser calls store.deleteUser and returns true on success', async () => {
      const spy = vi.spyOn(store, 'deleteUser').mockResolvedValue({ toast: 'User deleted' })
      const result = await composable.deleteUser(1)
      expect(spy).toHaveBeenCalledWith(1)
      expect(result).toBe(true)
    })

    it('deleteUser returns false on error', async () => {
      vi.spyOn(store, 'deleteUser').mockRejectedValue(new Error('Delete failed'))
      const result = await composable.deleteUser(1)
      expect(result).toBe(false)
    })

    it('getUserById calls store.getUserById', () => {
      store.$patch({ users: [{ id: 1, name: 'Test' }] as any })
      const user = composable.getUserById(1)
      expect(user).toEqual({ id: 1, name: 'Test' })
    })
  })
})
