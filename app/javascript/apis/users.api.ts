/**
 * Users API
 * Admin user management endpoints
 */

import type { IUser, IUserHistory, IUserUpdate } from '@/types'
import { http } from '@/services/http.service'

interface UsersResponse {
  users: IUser[]
  histories: IUserHistory[]
}

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
