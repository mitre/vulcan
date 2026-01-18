/**
 * User-related TypeScript interfaces
 * Following Pinia best practices with explicit type definitions
 */

import type { IPagination } from './common'

/**
 * User interface matching Rails User model
 * All fields that can be returned by the API
 */
export interface IUser {
  id: number
  email: string
  name: string
  admin: boolean
  provider?: string | null
  uid?: string | null
  slack_user_id?: string | null
  // Status fields (returned by admin endpoints)
  locked?: boolean
  confirmed?: boolean
  sign_in_count?: number
  last_sign_in_at?: string | null
  created_at?: string
}

/**
 * Extended user detail (for user detail view)
 * Includes all tracking and membership info
 */
export interface IUserDetail extends IUser {
  updated_at: string
  current_sign_in_at: string | null
  current_sign_in_ip: string | null
  last_sign_in_ip: string | null
  confirmed_at: string | null
  locked_at: string | null
  failed_attempts: number
  memberships: IUserMembership[]
}

/**
 * User membership info
 */
export interface IUserMembership {
  id: number
  role: string
  type: string
  name: string | null
  membership_id: number
  created_at: string
}

/**
 * Invite user request
 */
export interface IUserInvite {
  email: string
  name: string
}

/**
 * Login credentials
 */
export interface IUserLogin {
  email: string
  password: string
}

/**
 * Registration data (matches Devise + custom fields)
 */
export interface IUserRegister {
  name: string
  email: string
  password: string
  password_confirmation: string
  slack_user_id?: string
}

/**
 * User update data
 */
export interface IUserUpdate {
  name?: string
  email?: string
  admin?: boolean
  slack_user_id?: string
}

/**
 * Auth store state interface
 */
export interface IAuthState {
  user: IUser | null
  loading: boolean
}

/**
 * Users store state interface
 */
export interface IUsersState {
  users: IUser[]
  histories: IUserHistory[]
  loading: boolean
  error: string | null
  pagination: IPagination | null
}

// IPagination is now imported from ./common

/**
 * Filter options for user listing
 */
export interface IUserFilters {
  search?: string
  provider?: 'all' | 'local' | 'external'
  role?: 'all' | 'admin' | 'user'
  status?: 'all' | 'active' | 'locked' | 'unconfirmed'
}

/**
 * User history/audit record
 */
export interface IUserHistory {
  id: number
  auditable_id: number
  auditable_type: string
  user_id: number | null
  action: string
  audited_changes: Record<string, unknown>
  version: number
  created_at: string
  remote_address?: string
  request_uuid?: string
  comment?: string
}

/**
 * API response types
 */
export interface IAuthResponse {
  success: boolean
  user?: IUser
  error?: string
  errors?: string[]
}

export interface IUsersResponse {
  users: IUser[]
  pagination: IPagination
}

export interface IUserDetailResponse {
  user: IUserDetail
}

export interface IUserActionResponse {
  toast: string
  user?: IUser
  error?: string
  details?: string[]
}
