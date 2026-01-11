import { http } from '@/services/http.service'

/**
 * Login with email and password
 * Modern /api/auth/* endpoint for SPA authentication
 */
export function login(email: string, password: string) {
  return http.post('/api/auth/login', {
    email,
    password,
  })
}

/**
 * Logout current user
 * Modern /api/auth/* endpoint for SPA authentication
 */
export function logout() {
  return http.delete('/api/auth/logout')
}

/**
 * Get current authenticated user
 * Modern /api/auth/* endpoint for SPA authentication
 */
export function getCurrentUser() {
  return http.get('/api/auth/me')
}

export function register(name: string, email: string, password: string, passwordConfirmation: string, slackUserId?: string) {
  const userData: Record<string, string> = {
    name,
    email,
    password,
    password_confirmation: passwordConfirmation,
  }

  // Only include slack_user_id if provided
  if (slackUserId) {
    userData.slack_user_id = slackUserId
  }

  return http.post('/users', { user: userData })
}

/**
 * Get current user profile
 */
export function getProfile() {
  return http.get('/users/edit')
}

/**
 * Update current user profile
 */
export interface IProfileUpdate {
  name?: string
  email?: string
  slack_user_id?: string
  password?: string
  password_confirmation?: string
  current_password: string
}

export function updateProfile(data: IProfileUpdate) {
  return http.put('/users', { user: data })
}

/**
 * Delete current user account
 */
export function deleteAccount() {
  return http.delete('/users')
}
