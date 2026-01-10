/**
 * Components API Tests
 *
 * Tests for component CRUD operations and revision history
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { http } from '@/services/http.service'
import * as componentsApi from '../components.api'

vi.mock('@/services/http.service', () => ({
  http: {
    get: vi.fn(),
    post: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
  },
}))

describe('componentsApi', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('getRevisionHistory', () => {
    it('posts to /components/history with project_id and name', async () => {
      const mockResponse = {
        data: [
          {
            component: { id: 1, name: 'Test Component', version: '1.0' },
            baseComponent: { prefix: 'TEST' },
            diffComponent: { prefix: 'TEST' },
            changes: {
              '001': { change: 'added' },
              '002': { change: 'updated' },
            },
          },
        ],
      }

      vi.mocked(http.post).mockResolvedValue(mockResponse)

      const result = await componentsApi.getRevisionHistory(123, 'Test Component')

      expect(http.post).toHaveBeenCalledWith('/components/history', {
        project_id: 123,
        name: 'Test Component',
      })
      expect(result).toEqual(mockResponse.data)
    })

    it('handles API errors gracefully', async () => {
      const error = new Error('Network error')
      vi.mocked(http.post).mockRejectedValue(error)

      await expect(componentsApi.getRevisionHistory(123, 'Test Component')).rejects.toThrow('Network error')
    })

    it('returns empty array when no history exists', async () => {
      vi.mocked(http.post).mockResolvedValue({ data: [] })

      const result = await componentsApi.getRevisionHistory(123, 'Test Component')

      expect(result).toEqual([])
    })
  })

  describe('existing API functions', () => {
    it('getComponents calls GET /components', async () => {
      await componentsApi.getComponents()
      expect(http.get).toHaveBeenCalledWith('/components')
    })

    it('getComponent calls GET /components/:id', async () => {
      await componentsApi.getComponent(123)
      expect(http.get).toHaveBeenCalledWith('/components/123')
    })
  })
})
