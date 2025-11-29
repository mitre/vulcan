/**
 * Components Composable
 * STIG component management operations
 */

import type { IComponentCreate, IComponentDuplicate, IComponentUpdate } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useComponentsStore } from '@/stores'
import { useAppToast } from './useToast'

export function useComponents() {
  const store = useComponentsStore()
  const toast = useAppToast()

  const { components, currentComponent, loading, error } = storeToRefs(store)
  const count = computed(() => components.value.length)
  const released = computed(() => components.value.filter(c => c.released))

  async function fetchById(id: number) {
    await store.fetchComponent(id)
    return currentComponent.value
  }

  async function create(data: IComponentCreate): Promise<boolean> {
    try {
      await store.createComponent(data)
      toast.success('Component created')
      return true
    }
    catch (err) {
      toast.error('Failed to create component', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function update(id: number, data: IComponentUpdate): Promise<boolean> {
    try {
      await store.updateComponent(id, data)
      toast.success('Component updated')
      return true
    }
    catch (err) {
      toast.error('Failed to update component', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function remove(id: number): Promise<boolean> {
    try {
      await store.deleteComponent(id)
      toast.success('Component deleted')
      return true
    }
    catch (err) {
      toast.error('Failed to delete component', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  async function duplicate(id: number, options: IComponentDuplicate): Promise<boolean> {
    try {
      await store.duplicateComponent(id, options)
      toast.success('Component duplicated')
      return true
    }
    catch (err) {
      toast.error('Failed to duplicate component', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  return { components, currentComponent, loading, error, count, released, fetchById, create, update, remove, duplicate }
}
