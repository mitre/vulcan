/**
 * Components Store
 * Component state management
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type { IComponent, IComponentCreate, IComponentDuplicate, IComponentUpdate } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import {
  createComponent,
  deleteComponent,
  duplicateComponent,
  getComponent,
  getComponents,
  updateComponent,
} from '@/apis/components.api'
import { removeItemFromList, updateItemInList, withAsyncAction } from '@/utils'

export const useComponentsStore = defineStore('components.store', () => {
  // State
  const components = ref<IComponent[]>([])
  const currentComponent = ref<IComponent | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const componentCount = computed(() => components.value.length)
  const getComponentById = computed(() => (id: number) => components.value.find(c => c.id === id))
  const releasedComponents = computed(() => components.value.filter(c => c.released))

  // Actions

  /**
   * Initialize from window.vueAppData (server-rendered data)
   */
  function initFromWindowData() {
    const windowData = (window as Window & { vueAppData?: { components?: IComponent[] } }).vueAppData
    if (windowData?.components) {
      components.value = windowData.components
    }
  }

  /**
   * Set components from project data
   */
  function setComponents(newComponents: IComponent[]) {
    components.value = newComponents
  }

  /**
   * Fetch all released components
   */
  async function fetchComponents() {
    return withAsyncAction(loading, error, 'Failed to fetch components', async () => {
      const response = await getComponents()
      components.value = response.data
      return response
    })
  }

  /**
   * Fetch a single component by ID
   */
  async function fetchComponent(id: number) {
    return withAsyncAction(loading, error, 'Failed to fetch component', async () => {
      const response = await getComponent(id)
      currentComponent.value = response.data
      return response
    })
  }

  /**
   * Create a new component
   */
  async function create(data: IComponentCreate) {
    return withAsyncAction(loading, error, 'Failed to create component', async () => {
      const response = await createComponent(data)
      return response
    })
  }

  /**
   * Update a component
   */
  async function update(id: number, data: IComponentUpdate) {
    return withAsyncAction(loading, error, 'Failed to update component', async () => {
      const response = await updateComponent(id, data)
      components.value = updateItemInList(components.value, id, data)
      if (currentComponent.value?.id === id) {
        currentComponent.value = { ...currentComponent.value, ...data }
      }
      return response
    })
  }

  /**
   * Delete a component
   */
  async function remove(id: number) {
    return withAsyncAction(loading, error, 'Failed to delete component', async () => {
      const response = await deleteComponent(id)
      components.value = removeItemFromList(components.value, id)
      if (currentComponent.value?.id === id) {
        currentComponent.value = null
      }
      return response
    })
  }

  /**
   * Duplicate a component
   */
  async function duplicate(id: number, options: IComponentDuplicate) {
    return withAsyncAction(loading, error, 'Failed to duplicate component', async () => {
      const response = await duplicateComponent(id, options)
      return response
    })
  }

  /**
   * Set current component
   */
  function setCurrentComponent(component: IComponent | null) {
    currentComponent.value = component
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    components.value = []
    currentComponent.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    components,
    currentComponent,
    loading,
    error,

    // Getters
    componentCount,
    getComponentById,
    releasedComponents,

    // Actions
    initFromWindowData,
    setComponents,
    fetchComponents,
    fetchComponent,
    createComponent: create,
    updateComponent: update,
    deleteComponent: remove,
    duplicateComponent: duplicate,
    setCurrentComponent,
    reset,
  }
})
