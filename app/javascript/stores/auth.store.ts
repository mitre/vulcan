/**
 * Auth Store
 * Current user authentication state
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 *
 * NOTE: Auth is the ONE exception where we read from window.vueAppData
 * because we need to know auth state before making any API calls.
 * Rails provides currentUser in the initial page load.
 */

import type { IProfileUpdate } from '@/apis/auth.api'
import type { IUser, IUserLogin, IUserRegister } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import {
  deleteAccount as apiDeleteAccount,
  getProfile as apiGetProfile,
  login as apiLogin,
  logout as apiLogout,
  register as apiRegister,
  updateProfile as apiUpdateProfile,
} from '@/apis/auth.api'
import { withAsyncAction } from '@/utils'

/**
 * Get initial user from window data (set by Rails on page load)
 */
function getInitialUser(): IUser | null {
  const windowData = (window as Window & { vueAppData?: { currentUser?: IUser } }).vueAppData
  return windowData?.currentUser || null
}

export const useAuthStore = defineStore('auth.store', () => {
  // State
  const user = ref<IUser | null>(getInitialUser())
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const signedIn = computed(() => !!user.value)
  const isAdmin = computed(() => user.value?.admin === true)
  const userEmail = computed(() => user.value?.email || '')
  const userName = computed(() => user.value?.name || '')
  const userId = computed(() => user.value?.id)

  // Actions

  /**
   * Set current user
   */
  function setUser(userData: IUser | null) {
    user.value = userData
  }

  /**
   * Clear current user
   */
  function clearUser() {
    user.value = null
  }

  /**
   * Login with email and password
   */
  async function login(credentials: IUserLogin) {
    return withAsyncAction(loading, error, 'Failed to login', async () => {
      const response = await apiLogin(credentials.email, credentials.password)
      setUser(response.data)
      return response
    })
  }

  /**
   * Logout current user
   */
  async function logout() {
    loading.value = true
    try {
      await apiLogout()
    }
    catch (err) {
      console.error('Logout API failed:', err)
    }
    finally {
      clearUser()
      loading.value = false
      window.location.href = '/users/sign_in'
    }
  }

  /**
   * Register new user
   */
  async function register(userData: IUserRegister) {
    return withAsyncAction(loading, error, 'Failed to register', async () => {
      const response = await apiRegister(
        userData.name,
        userData.email,
        userData.password,
        userData.password_confirmation,
        userData.slack_user_id,
      )
      return response
    })
  }

  /**
   * Fetch current user profile from API
   */
  async function fetchProfile() {
    return withAsyncAction(loading, error, 'Failed to fetch profile', async () => {
      const response = await apiGetProfile()
      setUser(response.data.user)
      return response
    })
  }

  /**
   * Update current user profile
   */
  async function updateProfile(data: IProfileUpdate) {
    return withAsyncAction(loading, error, 'Failed to update profile', async () => {
      const response = await apiUpdateProfile(data)
      if (response.data.success) {
        setUser(response.data.user)
      }
      return response
    })
  }

  /**
   * Delete current user account
   */
  async function deleteAccount() {
    loading.value = true
    try {
      await apiDeleteAccount()
      clearUser()
      window.location.href = '/users/sign_in'
    }
    finally {
      loading.value = false
    }
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    user.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    user,
    loading,
    error,

    // Getters
    signedIn,
    isAdmin,
    userEmail,
    userName,
    userId,

    // Actions
    setUser,
    clearUser,
    login,
    logout,
    register,
    fetchProfile,
    updateProfile,
    deleteAccount,
    reset,
  }
})
