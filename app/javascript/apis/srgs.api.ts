/**
 * Security Requirements Guides (SRGs) API
 */

import type { ISecurityRequirementsGuide, ISrgListItem } from '@/types'
import { http } from '@/services/http.service'

/**
 * Fetch all SRGs
 * GET /srgs
 */
export function getSrgs() {
  return http.get<ISecurityRequirementsGuide[]>('/srgs')
}

/**
 * Get a single SRG by ID
 * GET /srgs/:id
 */
export function getSrg(id: number) {
  return http.get<ISecurityRequirementsGuide>(`/srgs/${id}`)
}

/**
 * Get latest version of each SRG (for dropdowns)
 * GET /srgs/latest
 */
export function getLatestSrgs() {
  return http.get<ISrgListItem[]>('/srgs/latest')
}

/**
 * Upload new SRG
 * POST /srgs
 */
export function uploadSrg(file: File) {
  const formData = new FormData()
  formData.append('file', file)

  return http.post('/srgs', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

/**
 * Delete SRG
 * DELETE /srgs/:id
 */
export function deleteSrg(id: number) {
  return http.delete(`/srgs/${id}`)
}
