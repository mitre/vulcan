/**
 * Project-related TypeScript interfaces
 */

/**
 * Project membership
 */
export interface IProjectMembership {
  id: number
  user_id: number
  membership_type: string
  membership_id: number
  role: string
}

/**
 * Core Project interface matching Rails Project model
 */
export interface IProject {
  id: number
  name: string
  description?: string
  visibility: 'discoverable' | 'hidden'
  created_at: string
  updated_at: string
  memberships?: IProjectMembership[]
  admin?: boolean
  is_member?: boolean
  access_request_id?: number | null
}

/**
 * Project creation data
 */
export interface IProjectCreate {
  name: string
  description?: string
  visibility?: 'discoverable' | 'hidden'
  slack_channel_id?: string
}

/**
 * Project update data
 */
export interface IProjectUpdate {
  name?: string
  description?: string
  visibility?: 'discoverable' | 'hidden'
  project_metadata_attributes?: {
    data: Record<string, string>
  }
}

/**
 * Projects store state interface
 */
export interface IProjectsState {
  projects: IProject[]
  currentProject: IProject | null
  loading: boolean
  error: string | null
}
