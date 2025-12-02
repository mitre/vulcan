/**
 * Audit-related TypeScript interfaces
 * Following Pinia best practices with explicit type definitions
 *
 * Matches the Rails Audited gem + our custom blueprints
 */

import type { IPagination } from './common'

/**
 * Auditable types tracked by the system
 */
export type AuditableType
  = | 'User'
    | 'Project'
    | 'Component'
    | 'Rule'
    | 'Membership'
    | 'RuleDescription'
    | 'DisaRuleDescription'
    | 'Check'
    | 'AdditionalAnswer'
    | 'AdditionalQuestion'

/**
 * Audit action types
 */
export type AuditAction = 'create' | 'update' | 'destroy'

/**
 * Audit entry for list view (slim version from AuditIndexBlueprint)
 */
export interface IAudit {
  id: number
  auditable_type: AuditableType
  auditable_id: number
  action: AuditAction
  version: number
  user_id: number | null
  user_name: string
  remote_address: string | null
  created_at: string
  changes_summary: string
}

/**
 * Audit detail (full version from AuditBlueprint)
 */
export interface IAuditDetail extends IAudit {
  associated_type: string | null
  associated_id: number | null
  audited_changes: Record<string, unknown>
  comment: string | null
  request_uuid: string | null
  user_email: string | null
  auditable_exists: boolean
  auditable_name: string | null
}

/**
 * Filter options for audit listing
 */
export interface IAuditFilters {
  auditable_type?: AuditableType | ''
  action_type?: AuditAction | ''
  user_id?: number | ''
  from_date?: string
  to_date?: string
  search?: string
  page?: number
  per_page?: number
}

/**
 * Available filter options returned by API
 */
export interface IAuditFilterOptions {
  auditable_types: AuditableType[]
  actions: AuditAction[]
}

/**
 * Audit statistics
 */
export interface IAuditStats {
  total_audits: number
  audits_today: number
  audits_this_week: number
  by_type: Record<AuditableType, number>
  by_action: Record<AuditAction, number>
  cached_at: string
}

/**
 * Audit store state interface
 */
export interface IAuditState {
  audits: IAudit[]
  selectedAudit: IAuditDetail | null
  stats: IAuditStats | null
  filterOptions: IAuditFilterOptions | null
  loading: boolean
  statsLoading: boolean
  detailLoading: boolean
  error: string | null
  pagination: IPagination | null
  filters: IAuditFilters
}

/**
 * API response types
 */
export interface IAuditsResponse {
  audits: IAudit[]
  pagination: IPagination
  filters: IAuditFilterOptions
}

export interface IAuditDetailResponse {
  audit: IAuditDetail
}

export interface IAuditStatsResponse extends IAuditStats {}

/**
 * Change diff entry for display
 */
export interface IAuditChange {
  field: string
  old_value: unknown
  new_value: unknown
}

/**
 * Parsed audit changes for UI display
 */
export function parseAuditChanges(changes: Record<string, unknown>): IAuditChange[] {
  return Object.entries(changes).map(([field, value]) => {
    // Audited stores changes as [old_value, new_value] for updates
    // or just the value for creates
    if (Array.isArray(value) && value.length === 2) {
      return {
        field,
        old_value: value[0],
        new_value: value[1],
      }
    }
    return {
      field,
      old_value: null,
      new_value: value,
    }
  })
}

/**
 * Format audit action for display
 */
export function formatAuditAction(action: AuditAction): string {
  const actionMap: Record<AuditAction, string> = {
    create: 'Created',
    update: 'Updated',
    destroy: 'Deleted',
  }
  return actionMap[action] || action
}

/**
 * Get action badge variant for UI
 */
export function getActionVariant(action: AuditAction): string {
  const variantMap: Record<AuditAction, string> = {
    create: 'success',
    update: 'info',
    destroy: 'danger',
  }
  return variantMap[action] || 'secondary'
}
