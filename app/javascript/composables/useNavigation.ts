/**
 * Navigation Composable
 * Navigation links and access request notifications
 */

import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useNavigationStore } from '@/stores'

export function useNavigation() {
  const store = useNavigationStore()

  const { links, accessRequests, loading } = storeToRefs(store)
  const hasAccessRequests = computed(() => accessRequests.value.length > 0)
  const accessRequestCount = computed(() => accessRequests.value.length)

  async function refresh() {
    await store.fetchNavigation()
  }

  function removeAccessRequest(id: number) {
    store.removeAccessRequest(id)
  }

  function reset() {
    store.reset()
  }

  return { links, accessRequests, loading, hasAccessRequests, accessRequestCount, refresh, removeAccessRequest, reset }
}
