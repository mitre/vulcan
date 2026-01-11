/**
 * Auth API Client Tests
 *
 * Tests the modern /api/auth/* endpoints for SPA authentication
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { http } from '@/services/http.service'
import { getCurrentUser, login, logout } from '../auth.api'

vi.mock('@/services/http.service', () => ({
  http: {
    post: vi.fn(),
    delete: vi.fn(),
    get: vi.fn(),
  },
}))

describe('auth.api', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  describe('login', () => {
    const mockUser = {
      id: 1,
      email: 'test@example.com',
      admin: false,
    }

    beforeEach(() => {
      vi.mocked(http.post).mockResolvedValue({
        data: { user: mockUser },
        status: 200,
      })
    })

    it('calls POST /api/auth/login', async () => {
      await login('test@example.com', 'password123')

      expect(http.post).toHaveBeenCalledWith('/api/auth/login', {
        email: 'test@example.com',
        password: 'password123',
      })
    })

    it('returns user data from response', async () => {
      const result = await login('test@example.com', 'password123')

      expect(result.data.user).toEqual(mockUser)
      expect(result.data.user.id).toBe(1)
      expect(result.data.user.email).toBe('test@example.com')
    })

    it('handles empty email', async () => {
      await login('', 'password123')

      expect(http.post).toHaveBeenCalledWith('/api/auth/login', {
        email: '',
        password: 'password123',
      })
    })

    it('handles empty password', async () => {
      await login('test@example.com', '')

      expect(http.post).toHaveBeenCalledWith('/api/auth/login', {
        email: 'test@example.com',
        password: '',
      })
    })

    it('propagates 401 unauthorized errors', async () => {
      const mockError = {
        response: {
          status: 401,
          data: { error: 'Invalid credentials' },
        },
      }
      vi.mocked(http.post).mockRejectedValue(mockError)

      await expect(login('test@example.com', 'wrong')).rejects.toEqual(mockError)
    })

    it('propagates network errors', async () => {
      const mockError = new Error('Network error')
      vi.mocked(http.post).mockRejectedValue(mockError)

      await expect(login('test@example.com', 'password')).rejects.toThrow('Network error')
    })

    it('handles special characters in email', async () => {
      await login('user+test@example.com', 'password123')

      expect(http.post).toHaveBeenCalledWith('/api/auth/login', {
        email: 'user+test@example.com',
        password: 'password123',
      })
    })

    it('handles whitespace in credentials', async () => {
      await login('  test@example.com  ', '  password  ')

      expect(http.post).toHaveBeenCalledWith('/api/auth/login', {
        email: '  test@example.com  ',
        password: '  password  ',
      })
    })
  })

  describe('logout', () => {
    beforeEach(() => {
      vi.mocked(http.delete).mockResolvedValue({
        status: 204,
        data: '',
      })
    })

    it('calls DELETE /api/auth/logout', async () => {
      await logout()

      expect(http.delete).toHaveBeenCalledWith('/api/auth/logout')
    })

    it('returns response with 204 status', async () => {
      const result = await logout()

      expect(result.status).toBe(204)
    })

    it('propagates network errors', async () => {
      const mockError = new Error('Network error')
      vi.mocked(http.delete).mockRejectedValue(mockError)

      await expect(logout()).rejects.toThrow('Network error')
    })

    it('handles logout when not authenticated', async () => {
      // Logout should be idempotent (204 even if not logged in)
      await logout()

      expect(http.delete).toHaveBeenCalledWith('/api/auth/logout')
    })
  })

  describe('getCurrentUser', () => {
    const mockUser = {
      id: 1,
      email: 'test@example.com',
      admin: false,
    }

    beforeEach(() => {
      vi.mocked(http.get).mockResolvedValue({
        data: { user: mockUser },
        status: 200,
      })
    })

    it('calls GET /api/auth/me', async () => {
      await getCurrentUser()

      expect(http.get).toHaveBeenCalledWith('/api/auth/me')
    })

    it('returns user data from response', async () => {
      const result = await getCurrentUser()

      expect(result.data.user).toEqual(mockUser)
      expect(result.data.user.id).toBe(1)
      expect(result.data.user.email).toBe('test@example.com')
    })

    it('propagates 401 unauthorized errors', async () => {
      const mockError = {
        response: {
          status: 401,
          data: {},
        },
      }
      vi.mocked(http.get).mockRejectedValue(mockError)

      await expect(getCurrentUser()).rejects.toEqual(mockError)
    })

    it('propagates network errors', async () => {
      const mockError = new Error('Network error')
      vi.mocked(http.get).mockRejectedValue(mockError)

      await expect(getCurrentUser()).rejects.toThrow('Network error')
    })

    it('preserves user data structure', async () => {
      const result = await getCurrentUser()

      expect(result.data.user).toHaveProperty('id')
      expect(result.data.user).toHaveProperty('email')
      expect(result.data.user).toHaveProperty('admin')
      expect(typeof result.data.user.id).toBe('number')
      expect(typeof result.data.user.email).toBe('string')
      expect(typeof result.data.user.admin).toBe('boolean')
    })

    it('handles admin users', async () => {
      const adminUser = { ...mockUser, admin: true }
      vi.mocked(http.get).mockResolvedValue({
        data: { user: adminUser },
        status: 200,
      })

      const result = await getCurrentUser()

      expect(result.data.user.admin).toBe(true)
    })
  })
})
