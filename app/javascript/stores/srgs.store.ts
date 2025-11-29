/**
 * SRGs Store
 * Security Requirements Guides state management
 * Uses Options API pattern for consistency
 */

import type { ISecurityRequirementsGuide, ISrgsState } from '@/types'
import { defineStore } from 'pinia'
import { deleteSrg, getLatestSrgs, getSrg, getSrgs, uploadSrg } from '@/apis/srgs.api'

const initialState: ISrgsState = {
  srgs: [],
  latestSrgs: [],
  currentSrg: null,
  loading: false,
  error: null,
}

export const useSrgsStore = defineStore('srgs.store', {
  state: (): ISrgsState => ({ ...initialState }),

  getters: {
    srgCount: (state: ISrgsState) => state.srgs.length,
    getSrgById: (state: ISrgsState) => (id: number) => state.srgs.find(s => s.id === id),
  },

  actions: {
    /**
     * Fetch all SRGs
     */
    async fetchSrgs() {
      this.loading = true
      this.error = null
      try {
        const response = await getSrgs()
        this.srgs = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch SRGs'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Fetch latest version of each SRG
     */
    async fetchLatestSrgs() {
      this.loading = true
      this.error = null
      try {
        const response = await getLatestSrgs()
        this.latestSrgs = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch latest SRGs'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Fetch a single SRG by ID
     */
    async fetchSrg(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await getSrg(id)
        this.currentSrg = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch SRG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Upload new SRG
     */
    async uploadSrg(file: File) {
      this.loading = true
      this.error = null
      try {
        const response = await uploadSrg(file)
        // Refresh SRGs list after upload
        await this.fetchSrgs()
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to upload SRG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Delete SRG
     */
    async deleteSrg(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await deleteSrg(id)
        // Remove from local state
        this.srgs = this.srgs.filter(s => s.id !== id)
        if (this.currentSrg?.id === id) {
          this.currentSrg = null
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to delete SRG'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Set current SRG
     */
    setCurrentSrg(srg: ISecurityRequirementsGuide | null) {
      this.currentSrg = srg
    },

    /**
     * Clear store state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
