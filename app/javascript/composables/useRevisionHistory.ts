/**
 * useRevisionHistory Composable
 *
 * Manages component revision history fetching and state
 */

import { ref, watch } from 'vue'
import { getRevisionHistory as getRevisionHistoryApi } from '@/apis/components.api'

export interface IRevisionHistoryEntry {
  component: {
    id: number
    name: string
    version?: string
    release?: string
  }
  baseComponent: {
    prefix: string
  }
  diffComponent: {
    prefix: string
  }
  changes: Record<string, { change: 'added' | 'removed' | 'updated' }>
}

export function useRevisionHistory() {
  const selectedComponentName = ref('')
  const revisionHistory = ref<IRevisionHistoryEntry[]>([])
  const isLoading = ref(false)

  /**
   * Fetch revision history for selected component
   */
  async function fetchRevisionHistory(projectId: number) {
    if (!selectedComponentName.value) {
      return
    }

    isLoading.value = true
    try {
      const history = await getRevisionHistoryApi(projectId, selectedComponentName.value)
      revisionHistory.value = history
    }
    catch (error) {
      isLoading.value = false
      throw error
    }
    finally {
      isLoading.value = false
    }
  }

  // Clear history when component name changes to empty
  watch(selectedComponentName, (newValue) => {
    if (!newValue) {
      revisionHistory.value = []
    }
  })

  return {
    selectedComponentName,
    revisionHistory,
    isLoading,
    fetchRevisionHistory,
  }
}
