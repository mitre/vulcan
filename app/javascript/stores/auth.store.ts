/**
 * Auth Store
 * Current user authentication state
 * Uses Options API pattern for consistency with other stores
 *
 * NOTE: Auth is the ONE exception where we read from window.vueAppData
 * because we need to know auth state before making any API calls.
 * Rails provides currentUser in the initial page load.
 */

import type { IAuthState, IUser, IUserLogin, IUserRegister } from '@/types'
import { defineStore } from 'pinia'
import { login as apiLogin, logout as apiLogout, register as apiRegister } from '@/apis/auth.api'

/**
 * Get initial user from window data (set by Rails on page load)
 */
function getInitialUser(): IUser | null {
  const windowData = (window as Window & { vueAppData?: { currentUser?: IUser } }).vueAppData
  return windowData?.currentUser || null
}

const initialState: IAuthState = {
  user: getInitialUser(),
  loading: false,
}

export const useAuthStore = defineStore('auth.store', {
  state: (): IAuthState => ({ ...initialState }),

  getters: {
    signedIn: (state: IAuthState) => !!state.user,
    isAdmin: (state: IAuthState) => state.user?.admin === true,
    userEmail: (state: IAuthState) => state.user?.email || '',
    userName: (state: IAuthState) => state.user?.name || '',
    userId: (state: IAuthState) => state.user?.id,
  },

  actions: {
    /**
     * Set current user
     */
    setUser(userData: IUser | null) {
      this.user = userData
    },

    /**
     * Clear current user
     */
    clearUser() {
      this.user = null
    },

    /**
     * Login with email and password
     */
    async login(credentials: IUserLogin) {
      this.loading = true
      try {
        const response = await apiLogin(credentials.email, credentials.password)
        this.setUser(response.data)
        return response
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Logout current user
     */
    async logout() {
      this.loading = true
      try {
        await apiLogout()
      }
      catch (error) {
        console.error('Logout API failed:', error)
      }
      finally {
        this.clearUser()
        this.loading = false
        window.location.href = '/users/sign_in'
      }
    },

    /**
     * Register new user
     */
    async register(userData: IUserRegister) {
      this.loading = true
      try {
        const response = await apiRegister(
          userData.name,
          userData.email,
          userData.password,
          userData.password_confirmation,
          userData.slack_user_id,
        )
        return response
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Reset store to initial state
     */
    reset() {
      this.user = null
      this.loading = false
    },
  },
})
