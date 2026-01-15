/**
 * Settings API
 * Public application settings (no auth required)
 */

import { http } from '@/services/http.service'

export interface IConsentBanner {
  enabled: boolean
  version: number
  content: string
}

/**
 * Fetch consent banner configuration
 * GET /api/settings/consent_banner
 *
 * No authentication required - shown before login
 */
export function fetchConsentBanner() {
  return http.get<IConsentBanner>('/api/settings/consent_banner')
}
