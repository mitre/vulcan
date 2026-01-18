/**
 * useReleaseCheck Composable Tests
 */

import { beforeEach, describe, expect, it, vi } from 'vitest'
import { githubApi } from '@/apis/github.api'

import { useReleaseCheck } from '../useReleaseCheck'

// Mock the github API
vi.mock('@/apis/github.api', () => ({
  githubApi: {
    getLatestRelease: vi.fn(),
  },
}))

// Mock package.json version
vi.mock('../../../../package.json', () => ({
  version: '2.2.0',
}))

describe('useReleaseCheck', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('initial state', () => {
    it('has empty latestRelease', () => {
      const { latestRelease } = useReleaseCheck()
      expect(latestRelease.value).toBe('')
    })

    it('has updateAvailable as false', () => {
      const { updateAvailable } = useReleaseCheck()
      expect(updateAvailable.value).toBe(false)
    })

    it('has loading as false', () => {
      const { loading } = useReleaseCheck()
      expect(loading.value).toBe(false)
    })

    it('has null error', () => {
      const { error } = useReleaseCheck()
      expect(error.value).toBeNull()
    })

    it('exposes currentVersion from package.json', () => {
      const { currentVersion } = useReleaseCheck()
      expect(currentVersion).toBe('2.2.0')
    })
  })

  describe('fetchLatestRelease', () => {
    it('sets latestRelease on success', async () => {
      vi.mocked(githubApi.getLatestRelease).mockResolvedValue({
        tag_name: 'v2.3.0',
        name: 'v2.3.0',
        published_at: '2024-01-01T00:00:00Z',
        html_url: 'https://github.com/mitre/vulcan/releases/tag/v2.3.0',
        body: 'Release notes',
      })

      const { fetchLatestRelease, latestRelease } = useReleaseCheck()
      await fetchLatestRelease()

      expect(latestRelease.value).toBe('2.3.0')
    })

    it('sets updateAvailable when newer version exists', async () => {
      vi.mocked(githubApi.getLatestRelease).mockResolvedValue({
        tag_name: 'v2.3.0',
        name: 'v2.3.0',
        published_at: '2024-01-01T00:00:00Z',
        html_url: '',
        body: '',
      })

      const { fetchLatestRelease, updateAvailable } = useReleaseCheck()
      await fetchLatestRelease()

      expect(updateAvailable.value).toBe(true)
    })

    it('keeps updateAvailable false when current version is newer', async () => {
      vi.mocked(githubApi.getLatestRelease).mockResolvedValue({
        tag_name: 'v2.1.0',
        name: 'v2.1.0',
        published_at: '2024-01-01T00:00:00Z',
        html_url: '',
        body: '',
      })

      const { fetchLatestRelease, updateAvailable } = useReleaseCheck()
      await fetchLatestRelease()

      expect(updateAvailable.value).toBe(false)
    })

    it('keeps updateAvailable false when versions are equal', async () => {
      vi.mocked(githubApi.getLatestRelease).mockResolvedValue({
        tag_name: 'v2.2.0',
        name: 'v2.2.0',
        published_at: '2024-01-01T00:00:00Z',
        html_url: '',
        body: '',
      })

      const { fetchLatestRelease, updateAvailable } = useReleaseCheck()
      await fetchLatestRelease()

      expect(updateAvailable.value).toBe(false)
    })

    it('sets loading state during fetch', async () => {
      let resolvePromise: (value: unknown) => void
      vi.mocked(githubApi.getLatestRelease).mockReturnValue(
        new Promise((resolve) => { resolvePromise = resolve }),
      )

      const { fetchLatestRelease, loading } = useReleaseCheck()
      const promise = fetchLatestRelease()

      expect(loading.value).toBe(true)

      resolvePromise!({
        tag_name: 'v2.3.0',
        name: 'v2.3.0',
        published_at: '',
        html_url: '',
        body: '',
      })
      await promise

      expect(loading.value).toBe(false)
    })

    it('sets error on failure', async () => {
      vi.mocked(githubApi.getLatestRelease).mockRejectedValue(new Error('Network error'))

      const { fetchLatestRelease, error, latestRelease, updateAvailable } = useReleaseCheck()
      await fetchLatestRelease()

      expect(error.value).toBe('Network error')
      expect(latestRelease.value).toBe('')
      expect(updateAvailable.value).toBe(false)
    })
  })

  describe('dismissUpdate', () => {
    it('sets updateAvailable to false', async () => {
      vi.mocked(githubApi.getLatestRelease).mockResolvedValue({
        tag_name: 'v2.3.0',
        name: 'v2.3.0',
        published_at: '',
        html_url: '',
        body: '',
      })

      const { fetchLatestRelease, dismissUpdate, updateAvailable } = useReleaseCheck()
      await fetchLatestRelease()
      expect(updateAvailable.value).toBe(true)

      dismissUpdate()
      expect(updateAvailable.value).toBe(false)
    })
  })
})
