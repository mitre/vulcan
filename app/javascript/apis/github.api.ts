/**
 * GitHub API
 *
 * API client for GitHub release information.
 * Used to check for application updates.
 */

export interface IGitHubRelease {
  tag_name: string
  name: string
  published_at: string
  html_url: string
  body: string
}

/**
 * Fetch the latest release from a GitHub repository
 */
export async function getLatestRelease(owner: string, repo: string): Promise<IGitHubRelease> {
  const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases/latest`)
  if (!response.ok) {
    throw new Error(`Failed to fetch release: ${response.status}`)
  }
  return response.json()
}

export const githubApi = {
  getLatestRelease,
}
