/**
 * GitHub API Tests
 */

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { getLatestRelease, githubApi } from '../github.api'

describe('gitHub API', () => {
  const mockRelease = {
    tag_name: 'v2.3.0',
    name: 'Version 2.3.0',
    published_at: '2024-01-15T00:00:00Z',
    html_url: 'https://github.com/mitre/vulcan/releases/tag/v2.3.0',
    body: 'Release notes content',
  }

  beforeEach(() => {
    vi.spyOn(globalThis, 'fetch')
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  describe('getLatestRelease', () => {
    it('fetches latest release from GitHub API', async () => {
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockRelease),
      } as Response)

      const result = await getLatestRelease('mitre', 'vulcan')

      expect(fetch).toHaveBeenCalledWith(
        'https://api.github.com/repos/mitre/vulcan/releases/latest',
      )
      expect(result).toEqual(mockRelease)
    })

    it('throws error when response is not ok', async () => {
      vi.mocked(fetch).mockResolvedValue({
        ok: false,
        status: 404,
        json: () => Promise.resolve({ message: 'Not Found' }),
      } as Response)

      await expect(getLatestRelease('mitre', 'vulcan')).rejects.toThrow(
        'Failed to fetch release: 404',
      )
    })

    it('works with different owner/repo combinations', async () => {
      vi.mocked(fetch).mockResolvedValue({
        ok: true,
        json: () => Promise.resolve(mockRelease),
      } as Response)

      await getLatestRelease('other-org', 'other-repo')

      expect(fetch).toHaveBeenCalledWith(
        'https://api.github.com/repos/other-org/other-repo/releases/latest',
      )
    })
  })

  describe('githubApi object', () => {
    it('exports getLatestRelease function', () => {
      expect(githubApi.getLatestRelease).toBe(getLatestRelease)
    })
  })
})
