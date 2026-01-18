/**
 * Users Composable
 * User management operations
 *
 * Architecture: API → Store → Composable → Page
 * Pages use this composable, never the store directly.
 */

import type { IUserFilters, IUserInvite, IUserUpdate } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useUsersStore } from '@/stores'
import { useAppToast } from './useToast'

export function useUsers() {
  const store = useUsersStore()
  const toast = useAppToast()

  // Reactive refs from store
  const { users, pagination, filters, loading, error } = storeToRefs(store)

  // Computed getters
  const userCount = computed(() => store.userCount)
  const adminCount = computed(() => store.adminCount)
  const lockedCount = computed(() => store.lockedCount)
  const currentPage = computed(() => store.currentPage)
  const totalPages = computed(() => store.totalPages)
  const hasActiveFilters = computed(() => store.hasActiveFilters)

  // Actions
  async function fetchUsers(page: number = 1) {
    try {
      await store.fetchAdminUsers(page)
    }
    catch (err) {
      toast.error('Failed to load users', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  async function setFilters(newFilters: Partial<IUserFilters>) {
    try {
      await store.setFilters(newFilters)
    }
    catch (err) {
      toast.error('Failed to filter users', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  async function clearFilters() {
    try {
      await store.clearFilters()
    }
    catch (err) {
      toast.error('Failed to clear filters', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  async function goToPage(page: number) {
    try {
      await store.goToPage(page)
    }
    catch (err) {
      toast.error('Failed to load page', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  async function lockUser(id: number): Promise<boolean> {
    try {
      const result = await store.lockUser(id)
      toast.success(result.toast || 'User locked')
      return true
    }
    catch (err) {
      toast.error('Failed to lock user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function unlockUser(id: number): Promise<boolean> {
    try {
      const result = await store.unlockUser(id)
      toast.success(result.toast || 'User unlocked')
      return true
    }
    catch (err) {
      toast.error('Failed to unlock user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function resetPassword(id: number): Promise<boolean> {
    try {
      const result = await store.resetPassword(id)
      toast.success(result.toast || 'Password reset email sent')
      return true
    }
    catch (err) {
      toast.error('Failed to send password reset', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function resendConfirmation(id: number): Promise<boolean> {
    try {
      const result = await store.resendConfirmation(id)
      toast.success(result.toast || 'Confirmation email sent')
      return true
    }
    catch (err) {
      toast.error('Failed to send confirmation', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function inviteUser(data: IUserInvite): Promise<boolean> {
    try {
      const result = await store.inviteUser(data)
      toast.success(result.toast || 'Invitation sent')
      return true
    }
    catch (err) {
      toast.error('Failed to invite user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function updateUser(id: number, data: IUserUpdate): Promise<boolean> {
    try {
      const result = await store.updateUser(id, data)
      toast.success(result.toast || 'User updated')
      return true
    }
    catch (err) {
      toast.error('Failed to update user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function deleteUser(id: number): Promise<boolean> {
    try {
      const result = await store.deleteUser(id)
      toast.success(result.toast || 'User deleted')
      return true
    }
    catch (err) {
      toast.error('Failed to delete user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  function getUserById(id: number) {
    return store.getUserById(id)
  }

  return {
    // State
    users,
    pagination,
    filters,
    loading,
    error,
    // Computed
    userCount,
    adminCount,
    lockedCount,
    currentPage,
    totalPages,
    hasActiveFilters,
    // Actions
    fetchUsers,
    setFilters,
    clearFilters,
    goToPage,
    lockUser,
    unlockUser,
    resetPassword,
    resendConfirmation,
    inviteUser,
    updateUser,
    deleteUser,
    getUserById,
  }
}
