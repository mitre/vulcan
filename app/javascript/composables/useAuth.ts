/**
 * Auth Composable
 * Provides reactive access to authentication state and operations
 *
 * Usage:
 *   const { user, isAdmin, signedIn, login, logout } = useAuth()
 */

import type { IUserLogin, IUserRegister } from '@/types'
import { storeToRefs } from 'pinia'
import { useAuthStore } from '@/stores'
import { useAppToast } from './useToast'

export function useAuth() {
  const store = useAuthStore()
  const toast = useAppToast()

  // Use storeToRefs to maintain reactivity when destructuring
  const { user, loading } = storeToRefs(store)

  // Re-export getters as computed-like refs
  const signedIn = storeToRefs(store).user // Will be truthy when logged in
  const isAdmin = store.isAdmin
  const userEmail = store.userEmail
  const userName = store.userName

  /**
   * Login with credentials
   * @returns true if successful, false if failed
   */
  async function login(credentials: IUserLogin): Promise<boolean> {
    try {
      await store.login(credentials)
      toast.success('Successfully logged in')
      return true
    }
    catch (err) {
      toast.error('Login failed', err instanceof Error ? err.message : 'Invalid credentials')
      return false
    }
  }

  /**
   * Logout current user
   */
  async function logout(): Promise<void> {
    await store.logout()
    // Note: store.logout redirects to login page
  }

  /**
   * Register new user
   * @returns true if successful, false if failed
   */
  async function register(userData: IUserRegister): Promise<boolean> {
    try {
      await store.register(userData)
      toast.success('Registration successful. Please check your email to confirm your account.')
      return true
    }
    catch (err) {
      toast.error('Registration failed', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  return {
    // Reactive state
    user,
    loading,

    // Computed-like getters
    signedIn,
    isAdmin,
    userEmail,
    userName,

    // Actions
    login,
    logout,
    register,
  }
}
