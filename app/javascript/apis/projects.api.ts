/**
 * Projects API
 * Project CRUD endpoints
 */

import type { IProject, IProjectCreate, IProjectUpdate } from '@/types'
import { http } from '@/services/http.service'

/**
 * Fetch all projects for current user
 * GET /projects
 */
export function getProjects() {
  return http.get<IProject[]>('/projects')
}

/**
 * Get a single project by ID
 * GET /projects/:id
 */
export function getProject(id: number) {
  return http.get<IProject>(`/projects/${id}`)
}

/**
 * Create a new project
 * POST /projects
 */
export function createProject(data: IProjectCreate) {
  return http.post('/projects', { project: data })
}

/**
 * Update a project
 * PATCH /projects/:id
 */
export function updateProject(id: number, data: IProjectUpdate) {
  return http.patch(`/projects/${id}`, { project: data })
}

/**
 * Delete a project
 * DELETE /projects/:id
 */
export function deleteProject(id: number) {
  return http.delete(`/projects/${id}`)
}

/**
 * Search projects by SRG
 * GET /projects/search?q=:query
 */
export function searchProjects(query: string) {
  return http.get('/projects/search', { params: { q: query } })
}
