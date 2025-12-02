/**
 * STIGs Store
 * Security Technical Implementation Guides state management
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type { IStig } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { deleteStig, getStig, getStigs, uploadStig } from '@/apis/stigs.api'
import { removeItemFromList, withAsyncAction } from '@/utils'

export const useStigsStore = defineStore('stigs.store', () => {
  // State
  const stigs = ref<IStig[]>([])
  const currentStig = ref<IStig | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const stigCount = computed(() => stigs.value.length)
  const getStigById = computed(() => (id: number) => stigs.value.find(s => s.id === id))

  // Actions

  /**
   * Fetch all STIGs
   */
  async function fetchStigs() {
    return withAsyncAction(loading, error, 'Failed to fetch STIGs', async () => {
      const response = await getStigs()
      stigs.value = response.data
      return response
    })
  }

  /**
   * Fetch a single STIG by ID
   */
  async function fetchStig(id: number) {
    return withAsyncAction(loading, error, 'Failed to fetch STIG', async () => {
      const response = await getStig(id)
      currentStig.value = response.data
      return response
    })
  }

  /**
   * Upload new STIG
   */
  async function upload(file: File) {
    return withAsyncAction(loading, error, 'Failed to upload STIG', async () => {
      const response = await uploadStig(file)
      await fetchStigs()
      return response
    })
  }

  /**
   * Delete STIG
   */
  async function remove(id: number) {
    return withAsyncAction(loading, error, 'Failed to delete STIG', async () => {
      const response = await deleteStig(id)
      stigs.value = removeItemFromList(stigs.value, id)
      if (currentStig.value?.id === id) {
        currentStig.value = null
      }
      return response
    })
  }

  /**
   * Set current STIG
   */
  function setCurrentStig(stig: IStig | null) {
    currentStig.value = stig
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    stigs.value = []
    currentStig.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    stigs,
    currentStig,
    loading,
    error,

    // Getters
    stigCount,
    getStigById,

    // Actions
    fetchStigs,
    fetchStig,
    uploadStig: upload,
    deleteStig: remove,
    setCurrentStig,
    reset,
  }
})
