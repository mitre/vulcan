/**
 * Admin API
 *
 * API client for admin endpoints (dashboard stats, settings).
 */

import { http } from '@/services/http.service'

// Types
export interface AdminStats {
  users: {
    total: number
    local: number
    external: number
    admins: number
    locked: number
  }
  projects: {
    total: number
    recent: number
  }
  components: {
    total: number
    released: number
  }
  stigs: {
    total: number
  }
  srgs: {
    total: number
  }
  recent_activity: AdminActivity[]
}

export interface AdminActivity {
  id: number
  action: string
  auditable_type: string
  auditable_name: string
  user_name: string
  created_at: string
}

export interface AdminSettings {
  authentication: {
    local_login: {
      enabled: boolean
      email_confirmation: boolean
      session_timeout_minutes: number
    }
    user_registration: {
      enabled: boolean
    }
    lockable: {
      enabled: boolean
      max_attempts: number
      unlock_in_minutes: number
    }
  }
  ldap: {
    enabled: boolean
    title: string
  }
  oidc: {
    enabled: boolean
    title: string
    issuer: string
  }
  smtp: {
    enabled: boolean
    address: string
    port: number
  }
  slack: {
    enabled: boolean
  }
  project: {
    create_permission_enabled: boolean
  }
  app: {
    url: string
    contact_email: string
  }
}

/**
 * Fetch admin dashboard stats
 */
export function getStats() {
  return http.get<AdminStats>('/admin/stats')
}

/**
 * Fetch admin settings (read-only)
 */
export function getSettings() {
  return http.get<AdminSettings>('/admin/settings')
}

export const adminApi = {
  getStats,
  getSettings,
}
