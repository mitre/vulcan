/**
 * Settings API
 * Public application settings (no auth required)
 */

import { http } from '@/services/http.service'

export interface IAppBanner {
  enabled: boolean
  text: string
  backgroundColor: string
  textColor: string
}

export interface IConsentBanner {
  enabled: boolean
  version: number
  title: string
  titleAlign: 'left' | 'center' | 'right'
  content: string
}

export interface ISettings {
  banners: {
    app: IAppBanner
    consent: IConsentBanner
  }
}

/**
 * Fetch all settings (consolidated endpoint)
 * GET /api/settings
 *
 * No authentication required - provides public UI configuration
 */
export function fetchSettings() {
  return http.get<ISettings>('/api/settings')
}

/**
 * Fetch consent banner configuration
 * GET /api/settings/consent_banner
 *
 * @deprecated Use fetchSettings() instead
 * No authentication required - shown before login
 */
export function fetchConsentBanner() {
  return http.get<IConsentBanner>('/api/settings/consent_banner')
}
