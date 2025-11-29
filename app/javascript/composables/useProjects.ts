/**
 * Projects Composable
 * Provides reactive access to Projects data and operations
 *
 * Usage:
 *   const { projects, loading, error, refresh, create, update, remove } = useProjects()
 */

import type { IProjectCreate, IProjectUpdate } from '@/types'
import { storeToRefs } from 'pinia'
import { computed } from 'vue'
import { useProjectsStore } from '@/stores'
import { useAppToast } from './useToast'

export function useProjects() {
  const store = useProjectsStore()
  const toast = useAppToast()

  // Use storeToRefs to maintain reactivity when destructuring
  const { projects, currentProject, loading, error } = storeToRefs(store)

  // Computed getters
  const count = computed(() => projects.value.length)
  const isEmpty = computed(() => projects.value.length === 0)
  const memberProjects = computed(() => projects.value.filter(p => p.is_member))
  const adminProjects = computed(() => projects.value.filter(p => p.admin))

  /**
   * Fetch all projects
   */
  async function refresh() {
    await store.fetchProjects()
  }

  /**
   * Fetch a single project by ID
   */
  async function fetchById(id: number) {
    await store.fetchProject(id)
    return currentProject.value
  }

  /**
   * Create a new project
   * @returns true if successful, false if failed
   */
  async function create(data: IProjectCreate): Promise<boolean> {
    try {
      await store.createProject(data)
      toast.success('Successfully created project')
      return true
    }
    catch (err) {
      toast.error('Failed to create project', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Update a project
   * @returns true if successful, false if failed
   */
  async function update(id: number, data: IProjectUpdate): Promise<boolean> {
    try {
      await store.updateProject(id, data)
      toast.success('Successfully updated project')
      return true
    }
    catch (err) {
      toast.error('Failed to update project', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Delete a project by ID
   * @returns true if successful, false if failed
   */
  async function remove(id: number): Promise<boolean> {
    try {
      await store.deleteProject(id)
      toast.success('Successfully deleted project')
      return true
    }
    catch (err) {
      toast.error('Failed to delete project', err instanceof Error ? err.message : 'Unknown error')
      return false
    }
  }

  /**
   * Find project by ID from local state
   */
  function findById(id: number) {
    return store.getProjectById(id)
  }

  /**
   * Reset store state
   */
  function reset() {
    store.reset()
  }

  return {
    // Reactive state
    projects,
    currentProject,
    loading,
    error,

    // Computed
    count,
    isEmpty,
    memberProjects,
    adminProjects,

    // Actions
    refresh,
    fetchById,
    create,
    update,
    remove,
    findById,
    reset,
  }
}
