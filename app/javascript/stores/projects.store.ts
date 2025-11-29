/**
 * Projects Store
 * Project list and CRUD state management
 * Uses Options API pattern for consistency
 */

import type { IProject, IProjectCreate, IProjectsState, IProjectUpdate } from '@/types'
import { defineStore } from 'pinia'
import {
  createProject,
  deleteProject,
  getProject,
  getProjects,
  updateProject,
} from '@/apis/projects.api'

const initialState: IProjectsState = {
  projects: [],
  currentProject: null,
  loading: false,
  error: null,
}

export const useProjectsStore = defineStore('projects.store', {
  state: (): IProjectsState => ({ ...initialState }),

  getters: {
    projectCount: (state: IProjectsState) => state.projects.length,
    getProjectById: (state: IProjectsState) => (id: number) => state.projects.find(p => p.id === id),
    memberProjects: (state: IProjectsState) => state.projects.filter(p => p.is_member),
    adminProjects: (state: IProjectsState) => state.projects.filter(p => p.admin),
  },

  actions: {
    /**
     * Fetch all projects from API
     */
    async fetchProjects() {
      this.loading = true
      this.error = null
      try {
        const response = await getProjects()
        this.projects = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch projects'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Fetch a single project by ID
     */
    async fetchProject(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await getProject(id)
        this.currentProject = response.data
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to fetch project'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Create a new project
     */
    async createProject(data: IProjectCreate) {
      this.loading = true
      this.error = null
      try {
        const response = await createProject(data)
        // Refresh projects list after creation
        await this.fetchProjects()
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to create project'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Update a project
     */
    async updateProject(id: number, data: IProjectUpdate) {
      this.loading = true
      this.error = null
      try {
        const response = await updateProject(id, data)
        // Update local state
        const index = this.projects.findIndex(p => p.id === id)
        if (index !== -1) {
          this.projects[index] = { ...this.projects[index], ...data }
        }
        if (this.currentProject?.id === id) {
          this.currentProject = { ...this.currentProject, ...data }
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to update project'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Delete a project
     */
    async deleteProject(id: number) {
      this.loading = true
      this.error = null
      try {
        const response = await deleteProject(id)
        // Remove from local state
        this.projects = this.projects.filter(p => p.id !== id)
        if (this.currentProject?.id === id) {
          this.currentProject = null
        }
        return response
      }
      catch (error) {
        this.error = error instanceof Error ? error.message : 'Failed to delete project'
        throw error
      }
      finally {
        this.loading = false
      }
    },

    /**
     * Set current project
     */
    setCurrentProject(project: IProject | null) {
      this.currentProject = project
    },

    /**
     * Clear store state
     */
    reset() {
      Object.assign(this, initialState)
    },
  },
})
