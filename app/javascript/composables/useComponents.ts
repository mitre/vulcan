/**
 * Components Composable
 * STIG component management operations
 */

import type { IComponentCreate, IComponentDuplicate, IComponentUpdate } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useComponentsStore } from '@/stores'
import { withToastBoolean } from '@/utils'
import { useAppToast } from './useToast'

export function useComponents() {
  const store = useComponentsStore()
  const toast = useAppToast()

  const { components, currentComponent, loading, error } = storeToRefs(store)
  const count = computed(() => components.value.length)
  const released = computed(() => components.value.filter(c => c.released))

  /**
   * Fetch all components
   */
  async function refresh() {
    try {
      await store.fetchComponents()
    }
    catch (err) {
      toast.error('Failed to load components', err instanceof Error ? err.message : 'Unknown error')
    }
  }

  /**
   * Fetch a single component by ID
   */
  async function fetchById(id: number) {
    await store.fetchComponent(id)
    return currentComponent.value
  }

  /**
   * Create a new component
   * @returns true if successful, false if failed
   */
  async function create(data: IComponentCreate): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Component created', error: 'Failed to create component' },
      () => store.createComponent(data),
    )
  }

  /**
   * Update a component
   * @returns true if successful, false if failed
   */
  async function update(id: number, data: IComponentUpdate): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Component updated', error: 'Failed to update component' },
      () => store.updateComponent(id, data),
    )
  }

  /**
   * Delete a component by ID
   * @returns true if successful, false if failed
   */
  async function remove(id: number): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Component deleted', error: 'Failed to delete component' },
      () => store.deleteComponent(id),
    )
  }

  /**
   * Duplicate a component
   * @returns true if successful, false if failed
   */
  async function duplicate(id: number, options: IComponentDuplicate): Promise<boolean> {
    return withToastBoolean(
      toast,
      { success: 'Component duplicated', error: 'Failed to duplicate component' },
      () => store.duplicateComponent(id, options),
    )
  }

  return {
    // Reactive state
    components,
    currentComponent,
    loading,
    error,

    // Computed
    count,
    released,

    // Actions
    refresh,
    fetchById,
    create,
    update,
    remove,
    duplicate,
  }
}
