/**
 * Audits API
 * Admin audit log endpoints
 *
 * All endpoints require admin authentication.
 * Uses the Audited gem's audit trail.
 */

import type {
  IAuditDetailResponse,
  IAuditFilters,
  IAuditsResponse,
  IAuditStatsResponse,
} from '@/types'
import { http } from '@/services/http.service'

/**
 * Build query params from filters, removing empty values
 */
function buildParams(filters: IAuditFilters): Record<string, string | number> {
  const params: Record<string, string | number> = {}

  if (filters.auditable_type) params.auditable_type = filters.auditable_type
  if (filters.action_type) params.action_type = filters.action_type
  if (filters.user_id) params.user_id = filters.user_id
  if (filters.from_date) params.from_date = filters.from_date
  if (filters.to_date) params.to_date = filters.to_date
  if (filters.search) params.search = filters.search
  if (filters.page) params.page = filters.page
  if (filters.per_page) params.per_page = filters.per_page

  return params
}

/**
 * Fetch audit log with pagination and filters
 * GET /admin/audits
 *
 * @param filters - Query filters (type, action, user, dates, search)
 */
export function getAudits(filters: IAuditFilters = {}) {
  return http.get<IAuditsResponse>('/admin/audits', {
    params: buildParams(filters),
  })
}

/**
 * Fetch single audit detail
 * GET /admin/audits/:id
 *
 * @param id - Audit record ID
 */
export function getAuditDetail(id: number) {
  return http.get<IAuditDetailResponse>(`/admin/audits/${id}`)
}

/**
 * Fetch audit statistics
 * GET /admin/audits/stats
 *
 * Returns aggregate counts cached for 5 minutes.
 */
export function getAuditStats() {
  return http.get<IAuditStatsResponse>('/admin/audits/stats')
}
