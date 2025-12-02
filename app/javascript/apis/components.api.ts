/**
 * Components API
 * Component CRUD endpoints
 */

import type { IComponent, IComponentCreate, IComponentDuplicate, IComponentUpdate } from '@/types'
import { http } from '@/services/http.service'

/**
 * Get all released components
 * GET /components
 */
export function getComponents() {
  return http.get<IComponent[]>('/components')
}

/**
 * Get a single component by ID
 * GET /components/:id
 */
export function getComponent(id: number) {
  return http.get<IComponent>(`/components/${id}`)
}

/**
 * Create a new component
 * POST /components
 */
export function createComponent(data: IComponentCreate) {
  return http.post('/components', { component: data })
}

/**
 * Update a component
 * PATCH /components/:id
 */
export function updateComponent(id: number, data: IComponentUpdate) {
  return http.patch(`/components/${id}`, { component: data })
}

/**
 * Delete a component
 * DELETE /components/:id
 */
export function deleteComponent(id: number) {
  return http.delete(`/components/${id}`)
}

/**
 * Duplicate a component
 * POST /components/:id/duplicate
 */
export function duplicateComponent(id: number, options: IComponentDuplicate) {
  return http.post(`/components/${id}/duplicate`, options)
}

/**
 * Export component
 * GET /components/:id/export
 */
export function exportComponent(id: number, type: 'excel' | 'xccdf' | 'inspec') {
  return http.get(`/components/${id}/export`, {
    params: { type },
    responseType: 'blob',
  })
}

/**
 * Upload spreadsheet to create/update component
 * POST /components (with file)
 */
export function uploadSpreadsheet(projectId: number, srgId: number, file: File) {
  const formData = new FormData()
  formData.append('component[project_id]', projectId.toString())
  formData.append('component[security_requirements_guide_id]', srgId.toString())
  formData.append('file', file)

  return http.post('/components', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

/**
 * Find rules in component by text search
 * POST /components/:id/find
 */
export function findRules(id: number, searchText: string) {
  return http.post(`/components/${id}/find`, { find: searchText })
}
