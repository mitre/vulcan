/**
 * Users Composable
 * Admin user management operations
 */

import type { IUserUpdate } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useUsersStore } from '@/stores'
import { useAppToast } from './useToast'

export function useUsers() {
  const store = useUsersStore()
  const toast = useAppToast()

  const { users, histories, loading, error } = storeToRefs(store)
  const count = computed(() => users.value.length)

  async function refresh() {
    await store.fetchUsers()
  }

  async function update(id: number, data: IUserUpdate): Promise<boolean> {
    try {
      await store.updateUser(id, data)
      toast.success('User updated')
      return true
    }
    catch (err) {
      toast.error('Failed to update user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function remove(id: number): Promise<boolean> {
    try {
      await store.deleteUser(id)
      toast.success('User deleted')
      return true
    }
    catch (err) {
      toast.error('Failed to delete user', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  return { users, histories, loading, error, count, refresh, update, remove }
}
