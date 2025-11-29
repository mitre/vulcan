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
