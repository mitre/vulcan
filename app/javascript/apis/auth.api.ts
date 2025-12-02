import { http } from '@/services/http.service'

export function login(email: string, password: string) {
  return http.post('/users/sign_in', {
    user: {
      email,
      password,
    },
  })
}

export function logout() {
  return http.delete('/users/sign_out')
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
