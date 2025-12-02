/**
 * SRGs Store
 * Security Requirements Guides state management
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type { ISecurityRequirementsGuide } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { deleteSrg, getLatestSrgs, getSrg, getSrgs, uploadSrg } from '@/apis/srgs.api'
import { removeItemFromList, withAsyncAction } from '@/utils'

export const useSrgsStore = defineStore('srgs.store', () => {
  // State
  const srgs = ref<ISecurityRequirementsGuide[]>([])
  const latestSrgs = ref<ISecurityRequirementsGuide[]>([])
  const currentSrg = ref<ISecurityRequirementsGuide | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const srgCount = computed(() => srgs.value.length)
  const getSrgById = computed(() => (id: number) => srgs.value.find(s => s.id === id))

  // Actions

  /**
   * Fetch all SRGs
   */
  async function fetchSrgs() {
    return withAsyncAction(loading, error, 'Failed to fetch SRGs', async () => {
      const response = await getSrgs()
      srgs.value = response.data
      return response
    })
  }

  /**
   * Fetch latest version of each SRG
   */
  async function fetchLatestSrgs() {
    return withAsyncAction(loading, error, 'Failed to fetch latest SRGs', async () => {
      const response = await getLatestSrgs()
      latestSrgs.value = response.data
      return response
    })
  }

  /**
   * Fetch a single SRG by ID
   */
  async function fetchSrg(id: number) {
    return withAsyncAction(loading, error, 'Failed to fetch SRG', async () => {
      const response = await getSrg(id)
      currentSrg.value = response.data
      return response
    })
  }

  /**
   * Upload new SRG
   */
  async function upload(file: File) {
    return withAsyncAction(loading, error, 'Failed to upload SRG', async () => {
      const response = await uploadSrg(file)
      await fetchSrgs()
      return response
    })
  }

  /**
   * Delete SRG
   */
  async function remove(id: number) {
    return withAsyncAction(loading, error, 'Failed to delete SRG', async () => {
      const response = await deleteSrg(id)
      srgs.value = removeItemFromList(srgs.value, id)
      if (currentSrg.value?.id === id) {
        currentSrg.value = null
      }
      return response
    })
  }

  /**
   * Set current SRG
   */
  function setCurrentSrg(srg: ISecurityRequirementsGuide | null) {
    currentSrg.value = srg
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    srgs.value = []
    latestSrgs.value = []
    currentSrg.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    srgs,
    latestSrgs,
    currentSrg,
    loading,
    error,

    // Getters
    srgCount,
    getSrgById,

    // Actions
    fetchSrgs,
    fetchLatestSrgs,
    fetchSrg,
    uploadSrg: upload,
    deleteSrg: remove,
    setCurrentSrg,
    reset,
  }
})
