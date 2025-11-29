/**
 * Navigation API
 * Fetch navigation data and access request notifications
 */

import type { IAccessRequestNotification, INavLink } from '@/types'
import { http } from '@/services/http.service'

/**
 * Get navigation links for current user
 * GET /api/navigation
 */
export function getNavigation() {
  return http.get<{ links: INavLink[], access_requests: IAccessRequestNotification[] }>('/api/navigation')
}

/**
 * Get pending access requests for admin users
 * GET /api/access_requests
 */
export function getAccessRequests() {
  return http.get<IAccessRequestNotification[]>('/api/access_requests')
}
