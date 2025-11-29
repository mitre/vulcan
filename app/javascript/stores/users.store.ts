/**
 * Users Store
 * Admin user management state (separate from auth store)
 * Uses Options API pattern for consistency
 */

import type { IUsersState, IUserUpdate } from '@/types'
import { defineStore } from 'pinia'
import { deleteUser, getUsers, updateUser } from '@/apis/users.api'

const initialState: IUsersState = {
  users: [],
  histories: [],
  loading: false,
  error: null,
}

export const useUsersStore = defineStore('users.store', {
  state: (): IUsersState => ({ ...initialState }),

  getters: {
    userCount: (state: IUsersState) => state.users.length,
    adminCount: (state: IUsersState) => state.users.filter(u => u.admin).length,
    getUserById: (state: IUsersState) => (id: number) => state.users.find(u => u.id === id),
  },

  actions: {
    /**
     * Fetch users from API (admin only)
     */
    async fetchUsers() {
      this.loading = true
      this.error = null
      try {
        const response = await getUsers()
        this.users = response.data.users
        this.histories = response.data.histories
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch users'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Update a user (admin status)
     */
    async updateUser(id: number, data: IUserUpdate) {
      this.loading = true
      this.error = null
      try {
        const response = await updateUser(id, data)
        // Update local state
        const index = this.users.findIndex(u => u.id === id)
        if (index !== -1) {
          this.users[index] = { ...this.users[index], ...data }
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to update user'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Delete a user
     */
    async deleteUser(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await deleteUser(id)
        // Remove from local state
        this.users = this.users.filter(u => u.id !== id)
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to delete user'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Clear store state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
