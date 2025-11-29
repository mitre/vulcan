/**
 * Navigation Store
 * Navigation links and access request notifications
 * Uses Options API pattern for consistency
 */

import type { INavigationState } from '@/types'
import { defineStore } from 'pinia'
import { getNavigation } from '@/apis/navigation.api'

const initialState: INavigationState = {
  links: [],
  accessRequests: [],
  loading: false,
}

export const useNavigationStore = defineStore('navigation.store', {
  state: (): INavigationState => ({ ...initialState }),

  getters: {
    hasAccessRequests: (state: INavigationState) => state.accessRequests.length > 0,
    accessRequestCount: (state: INavigationState) => state.accessRequests.length,
  },

  actions: {
    /**
     * Fetch navigation data from API
     */
    async fetchNavigation() {
      this.loading = true
      try {
        const response = await getNavigation()
        this.links = response.data.links
        this.accessRequests = response.data.access_requests || []
        return response
      }
      catch (error) {
        console.error('[NavigationStore] Failed to fetch navigation:', error)
        // Set default navigation on error
        this.links = [
          { icon: 'folder2-open', name: 'Projects', link: '/projects' },
          { icon: 'patch-check-fill', name: 'Released Components', link: '/components' },
          { icon: 'clipboard-check', name: 'STIGs', link: '/stigs' },
          { icon: 'clipboard', name: 'SRGs', link: '/srgs' },
        ]
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Clear an access request from the list (after approval/rejection)
     */
    removeAccessRequest(id: number) {
      this.accessRequests = this.accessRequests.filter(r => r.id !== id)
    },

    /**
     * Reset to initial state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
