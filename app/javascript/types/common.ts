/**
 * Common/shared type definitions
 * Base types used across multiple domain types
 */

/**
 * Timestamps mixin - common Rails fields
 */
export interface ITimestamps {
  created_at: string
  updated_at: string
}

/**
 * Base entity with ID and timestamps
 */
export interface IEntity extends ITimestamps {
  id: number
}

/**
 * Pagination info from server
 * Used by paginated list endpoints
 */
export interface IPagination {
  page: number
  per_page: number
  total: number
  total_pages: number
}

/**
 * Generic API error response
 */
export interface IApiError {
  error?: string
  errors?: string | string[]
  message?: string
}

/**
 * Base state interface for CRUD stores
 */
export interface IBaseCRUDState<T> {
  items: T[]
  current: T | null
  loading: boolean
  error: string | null
}

/**
 * Base state interface for paginated stores
 */
export interface IPaginatedState<T> extends IBaseCRUDState<T> {
  pagination: IPagination | null
}

/**
 * Resource identifiers
 */
export type ResourceId = number | string

/**
 * Generic list response wrapper
 */
export interface IListResponse<T> {
  data: T[]
  pagination?: IPagination
}

/**
 * Generic single item response wrapper
 */
export interface IItemResponse<T> {
  data: T
}

/**
 * Action response with toast message
 */
export interface IActionResponse {
  toast?: string
  success?: boolean
  error?: string
  redirect_url?: string
}
