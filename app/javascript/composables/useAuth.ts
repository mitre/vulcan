/**
 * Auth Composable
 * Provides reactive access to authentication state and operations
 *
 * Usage:
 *   const { user, isAdmin, signedIn, login, logout } = useAuth()
 */

import type { IProfileUpdate } from '@/apis/auth.api'
import type { IUser, IUserLogin, IUserRegister } from '@/types'
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
   * Check authentication status
   * Silently checks if user is authenticated without showing errors
   * @returns true if authenticated, false if not
   */
  async function checkAuth(): Promise<boolean> {
    try {
      const result = await store.checkAuth()
      // If result is null, user is not authenticated (401 response)
      return result !== null
    }
    catch {
      // Don't show error toast - authentication checks are often silent
      return false
    }
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

  /**
   * Resend email confirmation instructions
   * @returns true if successful, false if failed
   */
  async function resendConfirmation(email: string): Promise<boolean> {
    try {
      await store.resendConfirmation(email)
      toast.success('Confirmation instructions sent to your email', 'Check Your Email')
      return true
    }
    catch (err) {
      toast.error('Failed to send confirmation', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Resend account unlock instructions
   * @returns true if successful, false if failed
   */
  async function resendUnlock(email: string): Promise<boolean> {
    try {
      await store.resendUnlock(email)
      toast.success('Unlock instructions sent to your email', 'Check Your Email')
      return true
    }
    catch (err) {
      toast.error('Failed to send unlock instructions', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Request password reset instructions
   * @returns true if successful, false if failed
   */
  async function requestPasswordReset(email: string): Promise<boolean> {
    try {
      await store.requestPasswordReset(email)
      toast.success('Password reset instructions sent to your email', 'Check Your Email')
      return true
    }
    catch (err) {
      toast.error('Failed to send reset instructions', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Validate password reset token
   * @returns true if valid, false if invalid
   */
  async function validateResetToken(token: string): Promise<boolean> {
    try {
      const response = await store.validateResetToken(token)
      return response.data.valid === true
    }
    catch {
      return false
    }
  }

  /**
   * Reset password with token
   * @returns true if successful, false if failed
   */
  async function resetPassword(token: string, password: string, passwordConfirmation: string): Promise<boolean> {
    try {
      const response = await store.resetPassword(token, password, passwordConfirmation)
      if (response.data.success) {
        toast.success('Password changed successfully', 'Success')
        return true
      }
      else {
        toast.error(response.data.error || 'Failed to reset password')
        return false
      }
    }
    catch (err) {
      toast.error('Failed to reset password', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function getProfile(): Promise<IUser | null> {
    try {
      const response = await store.fetchProfile()
      if (response.data.user) {
        return response.data.user
      }
      return null
    }
    catch (err) {
      toast.error('Failed to load profile', err instanceof Error ? err.message : 'Unknown error')
      return null
    }
  }

  async function updateProfile(data: IProfileUpdate): Promise<boolean> {
    try {
      const response = await store.updateProfile(data)
      if (response.data.success) {
        toast.success(response.data.toast || 'Profile updated successfully', 'Success')
        return true
      }
      else {
        toast.error(response.data.error || 'Failed to update profile')
        return false
      }
    }
    catch (err) {
      toast.error('Failed to update profile', err instanceof Error ? err.message : 'Unknown error')
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
    checkAuth,
    register,
    resendConfirmation,
    resendUnlock,
    requestPasswordReset,
    validateResetToken,
    resetPassword,
    getProfile,
    updateProfile,
  }
}
