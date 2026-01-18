/**
 * SRGs Composable
 * Provides reactive access to SRGs data and operations
 *
 * Usage:
 *   const { srgs, loading, error, refresh, upload, remove } = useSrgs()
 */

import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useSrgsStore } from '@/stores'
import { withToastBoolean } from '@/utils'
import { useAppToast } from './useToast'

export function useSrgs() {
  const store = useSrgsStore()
  const toast = useAppToast()

  // Use storeToRefs to maintain reactivity when destructuring
  const { srgs, latestSrgs, currentSrg, loading, error } = storeToRefs(store)

  // Computed getters
  const count = computed(() => srgs.value.length)
  const isEmpty = computed(() => srgs.value.length === 0)

  /**
   * Fetch all SRGs
   */
  async function refresh() {
    await store.fetchSrgs()
  }

  /**
   * Fetch latest version of each SRG
   */
  async function refreshLatest() {
    await store.fetchLatestSrgs()
  }

  /**
   * Fetch a single SRG by ID
   */
  async function fetchById(id: number) {
    await store.fetchSrg(id)
    return currentSrg.value
  }

  /**
   * Upload a new SRG file
   * @returns true if successful, false if failed
   */
  async function upload(file: File): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Successfully uploaded SRG', error: 'Failed to upload SRG' },
      () => store.uploadSrg(file),
    )
  }

  /**
   * Delete an SRG by ID
   * @returns true if successful, false if failed
   */
  async function remove(id: number): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Successfully removed SRG', error: 'Failed to remove SRG' },
      () => store.deleteSrg(id),
    )
  }

  /**
   * Find SRG by ID from local state
   */
  function findById(id: number) {
    return store.getSrgById(id)
  }

  /**
   * Reset store state
   */
  function reset() {
    store.reset()
  }

  return {
    // Reactive state
    srgs,
    latestSrgs,
    currentSrg,
    loading,
    error,

    // Computed
    count,
    isEmpty,

    // Actions
    refresh,
    refreshLatest,
    fetchById,
    upload,
    remove,
    findById,
    reset,
  }
}
