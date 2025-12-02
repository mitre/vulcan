/**
 * Projects Store
 * Project list and CRUD state management
 *
 * Uses Composition API pattern (Vue 3 standard)
 * Architecture: API → Store → Composable → Page
 */

import type { IProject, IProjectCreate, IProjectUpdate } from '@/types'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import {
  createProject,
  deleteProject,
  getProject,
  getProjects,
  updateProject,
} from '@/apis/projects.api'
import {
  removeItemFromList,
  updateItemInList,
  withAsyncAction,
} from '@/utils'

export const useProjectsStore = defineStore('projects.store', () => {
  // State
  const projects = ref<IProject[]>([])
  const currentProject = ref<IProject | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  // Getters
  const projectCount = computed(() => projects.value.length)
  const getProjectById = computed(() => (id: number) => projects.value.find(p => p.id === id))
  const memberProjects = computed(() => projects.value.filter(p => p.is_member))
  const adminProjects = computed(() => projects.value.filter(p => p.admin))

  // Actions

  /**
   * Fetch all projects from API
   */
  async function fetchProjects() {
    return withAsyncAction(loading, error, 'Failed to fetch projects', async () => {
      const response = await getProjects()
      projects.value = response.data
      return response
    })
  }

  /**
   * Fetch a single project by ID
   */
  async function fetchProject(id: number) {
    return withAsyncAction(loading, error, 'Failed to fetch project', async () => {
      const response = await getProject(id)
      currentProject.value = response.data
      return response
    })
  }

  /**
   * Create a new project
   */
  async function create(data: IProjectCreate) {
    return withAsyncAction(loading, error, 'Failed to create project', async () => {
      const response = await createProject(data)
      await fetchProjects()
      return response
    })
  }

  /**
   * Update a project
   */
  async function update(id: number, data: IProjectUpdate) {
    return withAsyncAction(loading, error, 'Failed to update project', async () => {
      const response = await updateProject(id, data)
      projects.value = updateItemInList(projects.value, id, data)
      if (currentProject.value?.id === id) {
        currentProject.value = { ...currentProject.value, ...data }
      }
      return response
    })
  }

  /**
   * Delete a project
   */
  async function remove(id: number) {
    return withAsyncAction(loading, error, 'Failed to delete project', async () => {
      const response = await deleteProject(id)
      projects.value = removeItemFromList(projects.value, id)
      if (currentProject.value?.id === id) {
        currentProject.value = null
      }
      return response
    })
  }

  /**
   * Set current project
   */
  function setCurrentProject(project: IProject | null) {
    currentProject.value = project
  }

  /**
   * Reset store to initial state
   */
  function reset() {
    projects.value = []
    currentProject.value = null
    loading.value = false
    error.value = null
  }

  return {
    // State
    projects,
    currentProject,
    loading,
    error,

    // Getters
    projectCount,
    getProjectById,
    memberProjects,
    adminProjects,

    // Actions
    fetchProjects,
    fetchProject,
    createProject: create,
    updateProject: update,
    deleteProject: remove,
    setCurrentProject,
    reset,
  }
})
