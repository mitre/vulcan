/**
 * Components Store
 * Component state management
 * Uses Options API pattern for consistency
 */

import type { IComponent, IComponentCreate, IComponentDuplicate, IComponentsState, IComponentUpdate } from '@/types'
import { defineStore } from 'pinia'
import {
  createComponent,
  deleteComponent,
  duplicateComponent,
  getComponent,
  updateComponent,
} from '@/apis/components.api'

const initialState: IComponentsState = {
  components: [],
  currentComponent: null,
  loading: false,
  error: null,
}

export const useComponentsStore = defineStore('components.store', {
  state: (): IComponentsState => ({ ...initialState }),

  getters: {
    componentCount: (state: IComponentsState) => state.components.length,
    getComponentById: (state: IComponentsState) => (id: number) => state.components.find(c => c.id === id),
    releasedComponents: (state: IComponentsState) => state.components.filter(c => c.released),
  },

  actions: {
    /**
     * Initialize from window.vueAppData (server-rendered data)
     */
    initFromWindowData() {
      const windowData = (window as Window & { vueAppData?: { components?: IComponent[] } }).vueAppData
      if (windowData?.components) {
        this.components = windowData.components
      }
    },

    /**
     * Set components from project data
     */
    setComponents(components: IComponent[]) {
      this.components = components
    },

    /**
     * Fetch a single component by ID
     */
    async fetchComponent(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await getComponent(id)
        this.currentComponent = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch component'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Create a new component
     */
    async createComponent(data: IComponentCreate) {
      this.loading = true
      this.error = null
      try {
        const response = await createComponent(data)
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to create component'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Update a component
     */
    async updateComponent(id: number, data: IComponentUpdate) {
      this.loading = true
      this.error = null
      try {
        const response = await updateComponent(id, data)
        // Update local state
        const index = this.components.findIndex(c => c.id === id)
        if (index !== -1) {
          this.components[index] = { ...this.components[index], ...data }
        }
        if (this.currentComponent?.id === id) {
          this.currentComponent = { ...this.currentComponent, ...data }
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to update component'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Delete a component
     */
    async deleteComponent(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await deleteComponent(id)
        // Remove from local state
        this.components = this.components.filter(c => c.id !== id)
        if (this.currentComponent?.id === id) {
          this.currentComponent = null
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to delete component'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Duplicate a component
     */
    async duplicateComponent(id: number, options: IComponentDuplicate) {
      this.loading = true
      this.error = null
      try {
        const response = await duplicateComponent(id, options)
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to duplicate component'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Set current component
     */
    setCurrentComponent(component: IComponent | null) {
      this.currentComponent = component
    },

    /**
     * Clear store state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
