/**
 * Users Store
 * Admin user management state (separate from auth store)
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type { AdminUsersParams } from '@/apis/users.api'
import type {
  IPagination,
  IUser,
  IUserFilters,
  IUserHistory,
  IUserInvite,
  IUserUpdate,
} from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import {
  deleteAdminUser,
  getAdminUsers,
  inviteUser,
  lockUser,
  resendUserConfirmation,
  resetUserPassword,
  unlockUser,
  updateAdminUser,
} from '@/apis/users.api'
import { withAsyncAction } from '@/utils'

const initialFilters: IUserFilters = {
  search: '',
  provider: 'all',
  role: 'all',
  status: 'all',
}

export const useUsersStore = defineStore('users.store', () => {
  // State
  const users = ref<IUser[]>([])
  const histories = ref<IUserHistory[]>([])
  const pagination = ref<IPagination | null>(null)
  const filters = ref<IUserFilters>({ ...initialFilters })
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const userCount = computed(() => pagination.value?.total ?? users.value.length)
  const adminCount = computed(() => users.value.filter(u => u.admin).length)
  const lockedCount = computed(() => users.value.filter(u => u.locked).length)
  const getUserById = computed(() => (id: number) => users.value.find(u => u.id === id))
  const currentPage = computed(() => pagination.value?.page ?? 1)
  const totalPages = computed(() => pagination.value?.total_pages ?? 1)
  const hasActiveFilters = computed(() =>
    !!filters.value.search
    || filters.value.provider !== 'all'
    || filters.value.role !== 'all'
    || filters.value.status !== 'all',
  )

  // Actions

  /**
   * Fetch admin users with pagination and filters
   * GET /admin/users
   */
  async function fetchAdminUsers(page: number = 1) {
    return withAsyncAction(loading, error, 'Failed to fetch users', async () => {
      const params: AdminUsersParams = { page, per_page: 25 }

      // Apply filters (skip 'all' values)
      if (filters.value.search) {
        params.search = filters.value.search
      }
      if (filters.value.provider && filters.value.provider !== 'all') {
        params.provider = filters.value.provider
      }
      if (filters.value.role && filters.value.role !== 'all') {
        params.role = filters.value.role
      }
      if (filters.value.status && filters.value.status !== 'all') {
        params.status = filters.value.status
      }

      const response = await getAdminUsers(params)
      users.value = response.data.users
      pagination.value = response.data.pagination
      return response
    })
  }

  /**
   * Update filters and refetch
   */
  async function setFilters(newFilters: Partial<IUserFilters>) {
    filters.value = { ...filters.value, ...newFilters }
    await fetchAdminUsers(1) // Reset to page 1 when filters change
  }

  /**
   * Clear all filters
   */
  async function clearFilters() {
    filters.value = { ...initialFilters }
    await fetchAdminUsers(1)
  }

  /**
   * Go to specific page
   */
  async function goToPage(page: number) {
    await fetchAdminUsers(page)
  }

  /**
   * Lock a user account
   * POST /admin/users/:id/lock
   */
  async function lock(id: number) {
    const response = await lockUser(id)
    // Update local state
    const user = users.value.find(u => u.id === id)
    if (user && response.data.user) {
      user.locked = response.data.user.locked
    }
    return response.data
  }

  /**
   * Unlock a user account
   * POST /admin/users/:id/unlock
   */
  async function unlock(id: number) {
    const response = await unlockUser(id)
    // Update local state
    const user = users.value.find(u => u.id === id)
    if (user && response.data.user) {
      user.locked = response.data.user.locked
    }
    return response.data
  }

  /**
   * Send password reset email
   * POST /admin/users/:id/reset_password
   */
  async function resetPassword(id: number) {
    const response = await resetUserPassword(id)
    return response.data
  }

  /**
   * Resend confirmation email
   * POST /admin/users/:id/resend_confirmation
   */
  async function resendConfirmation(id: number) {
    const response = await resendUserConfirmation(id)
    return response.data
  }

  /**
   * Invite a new user
   * POST /admin/users/invite
   */
  async function invite(data: IUserInvite) {
    const response = await inviteUser(data)
    // Add to local state if successful
    if (response.data.user) {
      users.value.unshift(response.data.user)
      if (pagination.value) {
        pagination.value.total += 1
      }
    }
    return response.data
  }

  /**
   * Update a user
   * PATCH /admin/users/:id
   */
  async function update(id: number, data: IUserUpdate) {
    const response = await updateAdminUser(id, data)
    // Update local state
    const index = users.value.findIndex(u => u.id === id)
    if (index !== -1 && response.data.user) {
      users.value[index] = response.data.user
    }
    return response.data
  }

  /**
   * Delete a user
   * DELETE /admin/users/:id
   */
  async function remove(id: number) {
    const response = await deleteAdminUser(id)
    // Remove from local state
    users.value = users.value.filter(u => u.id !== id)
    if (pagination.value) {
      pagination.value.total -= 1
    }
    return response.data
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    users.value = []
    histories.value = []
    pagination.value = null
    filters.value = { ...initialFilters }
    loading.value = false
    error.value = null
  }

  return {
    // State
    users,
    histories,
    pagination,
    filters,
    loading,
    error,

    // Getters
    userCount,
    adminCount,
    lockedCount,
    getUserById,
    currentPage,
    totalPages,
    hasActiveFilters,

    // Actions
    fetchAdminUsers,
    setFilters,
    clearFilters,
    goToPage,
    lockUser: lock,
    unlockUser: unlock,
    resetPassword,
    resendConfirmation,
    inviteUser: invite,
    updateUser: update,
    deleteUser: remove,
    reset,
  }
})
