/**
 * Members API Client Tests
 *
 * Tests the axios-based API client for user search functionality.
 */

import axios from 'axios'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { SearchUsersResponse } from '../members.api'
import { searchUsers } from '../members.api'

vi.mock('axios')

describe('members.api', () => {
  afterEach(() => {
    vi.clearAllMocks()
  })

  describe('searchUsers', () => {
    const mockProjectId = 123
    const mockResponse: SearchUsersResponse = {
      users: [
        { id: 1, name: 'John Doe', email: 'john@example.com' },
        { id: 2, name: 'Jane Smith', email: 'jane@example.com' },
      ],
    }

    beforeEach(() => {
      vi.mocked(axios.get).mockResolvedValue({ data: mockResponse })
    })

    it('calls correct endpoint with project ID', async () => {
      await searchUsers({ projectId: mockProjectId, query: 'john' })

      expect(axios.get).toHaveBeenCalledWith(
        `/api/projects/${mockProjectId}/search_users`,
        expect.any(Object),
      )
    })

    it('passes query as q parameter', async () => {
      await searchUsers({ projectId: mockProjectId, query: 'john' })

      expect(axios.get).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          params: { q: 'john' },
        }),
      )
    })

    it('sets Accept header to application/json', async () => {
      await searchUsers({ projectId: mockProjectId, query: 'john' })

      expect(axios.get).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: { Accept: 'application/json' },
        }),
      )
    })

    it('returns response data', async () => {
      const result = await searchUsers({ projectId: mockProjectId, query: 'john' })

      expect(result).toEqual(mockResponse)
      expect(result.users).toHaveLength(2)
      expect(result.users[0].name).toBe('John Doe')
    })

    it('handles empty query string', async () => {
      await searchUsers({ projectId: mockProjectId, query: '' })

      expect(axios.get).toHaveBeenCalledWith(
        `/api/projects/${mockProjectId}/search_users`,
        expect.objectContaining({
          params: { q: '' },
        }),
      )
    })

    it('handles whitespace in query', async () => {
      await searchUsers({ projectId: mockProjectId, query: '  john  ' })

      expect(axios.get).toHaveBeenCalledWith(
        `/api/projects/${mockProjectId}/search_users`,
        expect.objectContaining({
          params: { q: '  john  ' },
        }),
      )
    })

    it('handles empty results', async () => {
      vi.mocked(axios.get).mockResolvedValue({ data: { users: [] } })

      const result = await searchUsers({ projectId: mockProjectId, query: 'xyz' })

      expect(result.users).toHaveLength(0)
    })

    it('propagates API errors', async () => {
      const mockError = new Error('Network error')
      vi.mocked(axios.get).mockRejectedValue(mockError)

      await expect(
        searchUsers({ projectId: mockProjectId, query: 'john' }),
      ).rejects.toThrow('Network error')
    })

    it('propagates 401 authentication errors', async () => {
      const mockError = {
        response: {
          status: 401,
          data: { error: 'Not authenticated' },
        },
      }
      vi.mocked(axios.get).mockRejectedValue(mockError)

      await expect(
        searchUsers({ projectId: mockProjectId, query: 'john' }),
      ).rejects.toEqual(mockError)
    })

    it('propagates 403 authorization errors', async () => {
      const mockError = {
        response: {
          status: 403,
          data: { error: 'Not authorized' },
        },
      }
      vi.mocked(axios.get).mockRejectedValue(mockError)

      await expect(
        searchUsers({ projectId: mockProjectId, query: 'john' }),
      ).rejects.toEqual(mockError)
    })

    it('handles different project IDs', async () => {
      await searchUsers({ projectId: 456, query: 'john' })

      expect(axios.get).toHaveBeenCalledWith(
        '/api/projects/456/search_users',
        expect.any(Object),
      )
    })

    it('handles special characters in query', async () => {
      const specialQuery = 'user@example.com'
      await searchUsers({ projectId: mockProjectId, query: specialQuery })

      expect(axios.get).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          params: { q: specialQuery },
        }),
      )
    })

    it('preserves user data structure', async () => {
      const result = await searchUsers({ projectId: mockProjectId, query: 'john' })

      result.users.forEach((user) => {
        expect(user).toHaveProperty('id')
        expect(user).toHaveProperty('name')
        expect(user).toHaveProperty('email')
        expect(typeof user.id).toBe('number')
        expect(typeof user.name).toBe('string')
        expect(typeof user.email).toBe('string')
      })
    })
  })
})
