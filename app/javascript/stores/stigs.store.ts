/**
 * STIGs Store
 * Security Technical Implementation Guides state management
 * Uses Options API pattern for consistency
 */

import type { IStig, IStigsState } from '@/types'
import { defineStore } from 'pinia'
import { deleteStig, getStig, getStigs, uploadStig } from '@/apis/stigs.api'

const initialState: IStigsState = {
  stigs: [],
  currentStig: null,
  loading: false,
  error: null,
}

export const useStigsStore = defineStore('stigs.store', {
  state: (): IStigsState => ({ ...initialState }),

  getters: {
    stigCount: (state: IStigsState) => state.stigs.length,
    getStigById: (state: IStigsState) => (id: number) => state.stigs.find(s => s.id === id),
  },

  actions: {
    /**
     * Fetch all STIGs
     */
    async fetchStigs() {
      this.loading = true
      this.error = null
      try {
        const response = await getStigs()
        this.stigs = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch STIGs'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Fetch a single STIG by ID
     */
    async fetchStig(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await getStig(id)
        this.currentStig = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch STIG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Upload new STIG
     */
    async uploadStig(file: File) {
      this.loading = true
      this.error = null
      try {
        const response = await uploadStig(file)
        // Refresh STIGs list after upload
        await this.fetchStigs()
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to upload STIG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Delete STIG
     */
    async deleteStig(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await deleteStig(id)
        // Remove from local state
        this.stigs = this.stigs.filter(s => s.id !== id)
        if (this.currentStig?.id === id) {
          this.currentStig = null
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to delete STIG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Set current STIG
     */
    setCurrentStig(stig: IStig | null) {
      this.currentStig = stig
    },

    /**
     * Clear store state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
