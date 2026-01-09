import axios from 'axios'

export interface SearchUsersParams {
  projectId: number
  query: string
}

export interface SearchUsersResponse {
  users: Array<{
    id: number
    name: string
    email: string
  }>
}

/**
 * Search for users to invite to a project
 * - Admin-only endpoint
 * - Excludes existing project members
 * - Minimum 2 characters
 * - Maximum 10 results
 */
export async function searchUsers(params: SearchUsersParams): Promise<SearchUsersResponse> {
  const response = await axios.get<SearchUsersResponse>(
    `/api/projects/${params.projectId}/search_users`,
    {
      params: { q: params.query },
      headers: { Accept: 'application/json' },
    },
  )
  return response.data
}
