/**
 * User-related TypeScript interfaces
 * Following Pinia best practices with explicit type definitions
 */

/**
 * Core User interface matching Rails User model
 * Fields: id, email, name, admin, provider, uid, slack_user_id
 */
export interface IUser {
  id: number
  email: string
  name: string
  admin: boolean
  provider?: string | null
  uid?: string | null
  slack_user_id?: string | null
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
 * User update data (for admin operations)
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
 * Users store state interface (for admin user management)
 */
export interface IUsersState {
  users: IUser[]
  histories: IUserHistory[]
  loading: boolean
  error: string | null
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
}
