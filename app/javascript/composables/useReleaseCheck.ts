/**
 * Release Check Composable
 *
 * Checks for application updates from GitHub releases.
 * Uses semver to compare versions.
 */

import semver from 'semver'
import { ref } from 'vue'
import { githubApi } from '@/apis/github.api'
import { version as currentVersion } from '../../../package.json'

const GITHUB_OWNER = 'mitre'
const GITHUB_REPO = 'vulcan'

export function useReleaseCheck() {
  const latestRelease = ref('')
  const updateAvailable = ref(false)
  const loading = ref(false)
  const error = ref<string | null>(null)

  /**
   * Clean version string by removing 'v' prefix
   */
  function cleanVersion(version: string): string {
    return version.replace(/^v/, '')
  }

  /**
   * Check if the latest version is greater than current
   */
  function isUpdateAvailable(latest: string, current: string): boolean {
    if (!latest || latest.trim() === '') return false

    try {
      const cleanLatest = cleanVersion(latest)
      const cleanCurrent = cleanVersion(current)
      return semver.gt(cleanLatest, cleanCurrent)
    }
    catch {
      // Silently handle version comparison errors
      return false
    }
  }

  /**
   * Fetch the latest release from GitHub
   */
  async function fetchLatestRelease(): Promise<void> {
    loading.value = true
    error.value = null

    try {
      const release = await githubApi.getLatestRelease(GITHUB_OWNER, GITHUB_REPO)
      latestRelease.value = release.tag_name.substring(1) // Remove 'v' prefix
      updateAvailable.value = isUpdateAvailable(latestRelease.value, currentVersion)
    }
    catch (err) {
      error.value = err instanceof Error ? err.message : 'Failed to check for updates'
      latestRelease.value = ''
      updateAvailable.value = false
    }
    finally {
      loading.value = false
    }
  }

  /**
   * Dismiss the update notification
   */
  function dismissUpdate(): void {
    updateAvailable.value = false
  }

  return {
    // State
    currentVersion,
    latestRelease,
    updateAvailable,
    loading,
    error,

    // Actions
    fetchLatestRelease,
    dismissUpdate,
  }
}
