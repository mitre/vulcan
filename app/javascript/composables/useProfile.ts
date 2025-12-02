/**
 * useProfile Composable
 *
 * Provides reactive access to the current user's profile with update functionality.
 * Follows the pattern: API → Store → Composable → Page
 */

import type { IProfileUpdate } from '@/apis/auth.api'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useAuthStore } from '@/stores'

export function useProfile() {
  const authStore = useAuthStore()
  const { user, loading } = storeToRefs(authStore)

  // Computed properties for profile display
  const name = computed(() => user.value?.name || '')
  const email = computed(() => user.value?.email || '')
  const slackUserId = computed(() => user.value?.slack_user_id || '')
  const isOAuthUser = computed(() => !!user.value?.provider)
  const provider = computed(() => user.value?.provider || null)

  /**
   * Fetch fresh profile data from API
   */
  async function refresh() {
    return authStore.fetchProfile()
  }

  /**
   * Update profile
   * @param data Profile update data (requires current_password for local users)
   */
  async function updateProfile(data: IProfileUpdate) {
    return authStore.updateProfile(data)
  }

  /**
   * Delete account
   */
  async function deleteAccount() {
    return authStore.deleteAccount()
  }

  return {
    // State
    user,
    loading,

    // Computed
    name,
    email,
    slackUserId,
    isOAuthUser,
    provider,

    // Actions
    refresh,
    updateProfile,
    deleteAccount,
  }
}
