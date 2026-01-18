/**
 * Users API
 * Admin user management endpoints
 *
 * Two endpoint groups:
 * - /users - Basic user CRUD (existing)
 * - /admin/users - Admin-specific operations with extended data
 */

import type {
  IUser,
  IUserActionResponse,
  IUserDetailResponse,
  IUserHistory,
  IUserInvite,
  IUsersResponse,
  IUserUpdate,
} from '@/types'
import { http } from '@/services/http.service'

interface UsersResponse {
  users: IUser[]
  histories: IUserHistory[]
}

// ============================================================================
// Basic User CRUD (/users)
// ============================================================================

/**
 * Fetch all users (admin only)
 * GET /users
 */
export function getUsers() {
  return http.get<UsersResponse>('/users')
}

/**
 * Update a user (admin only)
 * PATCH /users/:id
 */
export function updateUser(id: number, data: IUserUpdate) {
  return http.patch(`/users/${id}`, { user: data })
}

/**
 * Delete a user (admin only)
 * DELETE /users/:id
 */
export function deleteUser(id: number) {
  return http.delete(`/users/${id}`)
}

// ============================================================================
// Admin User Management (/admin/users)
// ============================================================================

export interface AdminUsersParams {
  page?: number
  per_page?: number
  search?: string
  provider?: 'local' | 'external'
  role?: 'admin' | 'user'
  status?: 'active' | 'locked' | 'unconfirmed'
}

/**
 * Fetch admin users list with pagination and filters
 * GET /admin/users
 */
export function getAdminUsers(params: AdminUsersParams = {}) {
  return http.get<IUsersResponse>('/admin/users', { params })
}

/**
 * Fetch single user detail for admin view
 * GET /admin/users/:id
 */
export function getAdminUserDetail(id: number) {
  return http.get<IUserDetailResponse>(`/admin/users/${id}`)
}

/**
 * Lock a user account
 * POST /admin/users/:id/lock
 */
export function lockUser(id: number) {
  return http.post<IUserActionResponse>(`/admin/users/${id}/lock`)
}

/**
 * Unlock a user account
 * POST /admin/users/:id/unlock
 */
export function unlockUser(id: number) {
  return http.post<IUserActionResponse>(`/admin/users/${id}/unlock`)
}

/**
 * Send password reset email to user
 * POST /admin/users/:id/reset_password
 */
export function resetUserPassword(id: number) {
  return http.post<IUserActionResponse>(`/admin/users/${id}/reset_password`)
}

/**
 * Resend confirmation email to user
 * POST /admin/users/:id/resend_confirmation
 */
export function resendUserConfirmation(id: number) {
  return http.post<IUserActionResponse>(`/admin/users/${id}/resend_confirmation`)
}

/**
 * Invite a new user (creates account and sends confirmation email)
 * POST /admin/users/invite
 */
export function inviteUser(data: IUserInvite) {
  return http.post<IUserActionResponse>('/admin/users/invite', { user: data })
}

/**
 * Update user as admin (can change any field including admin status)
 * PATCH /admin/users/:id
 */
export function updateAdminUser(id: number, data: IUserUpdate) {
  return http.patch<IUserActionResponse>(`/admin/users/${id}`, { user: data })
}

/**
 * Delete user as admin
 * DELETE /admin/users/:id
 */
export function deleteAdminUser(id: number) {
  return http.delete<IUserActionResponse>(`/admin/users/${id}`)
}
