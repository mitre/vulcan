/**
 * STIGs API
 */

import type { IStig } from '@/types'
import { http } from '@/services/http.service'

/**
 * Fetch all STIGs
 * GET /stigs
 */
export function getStigs() {
  return http.get<IStig[]>('/stigs')
}

/**
 * Get a single STIG by ID
 * GET /stigs/:id
 */
export function getStig(id: number) {
  return http.get<IStig>(`/stigs/${id}`)
}

/**
 * Upload new STIG
 * POST /stigs
 */
export function uploadStig(file: File) {
  const formData = new FormData()
  formData.append('file', file)

  return http.post('/stigs', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  })
}

/**
 * Delete STIG
 * DELETE /stigs/:id
 */
export function deleteStig(id: number) {
  return http.delete(`/stigs/${id}`)
}
