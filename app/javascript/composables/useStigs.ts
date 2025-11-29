/**
 * STIGs Composable
 * Provides reactive access to STIGs data and operations
 *
 * Usage:
 *   const { stigs, loading, error, refresh, upload, remove } = useStigs()
 */

import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useStigsStore } from '@/stores'
import { useAppToast } from './useToast'

export function useStigs() {
  const store = useStigsStore()
  const toast = useAppToast()

  // Use storeToRefs to maintain reactivity when destructuring
  const { stigs, currentStig, loading, error } = storeToRefs(store)

  // Computed getters
  const count = computed(() => stigs.value.length)
  const isEmpty = computed(() => stigs.value.length === 0)

  /**
   * Fetch all STIGs
   */
  async function refresh() {
    await store.fetchStigs()
  }

  /**
   * Fetch a single STIG by ID
   */
  async function fetchById(id: number) {
    await store.fetchStig(id)
    return currentStig.value
  }

  /**
   * Upload a new STIG file
   * @returns true if successful, false if failed
   */
  async function upload(file: File): Promise<boolean> {
    try {
      await store.uploadStig(file)
      toast.success('Successfully uploaded STIG')
      return true
    }
    catch (err) {
      toast.error('Failed to upload STIG', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Delete a STIG by ID
   * @returns true if successful, false if failed
   */
  async function remove(id: number): Promise<boolean> {
    try {
      await store.deleteStig(id)
      toast.success('Successfully removed STIG')
      return true
    }
    catch (err) {
      toast.error('Failed to remove STIG', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Find STIG by ID from local state
   */
  function findById(id: number) {
    return store.getStigById(id)
  }

  /**
   * Reset store state
   */
  function reset() {
    store.reset()
  }

  return {
    // Reactive state
    stigs,
    currentStig,
    loading,
    error,

    // Computed
    count,
    isEmpty,

    // Actions
    refresh,
    fetchById,
    upload,
    remove,
    findById,
    reset,
  }
}
