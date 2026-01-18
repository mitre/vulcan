/**
 * Project Access Request TypeScript interfaces
 */

import type { IProject } from './project'
import type { IUser } from './user'

/**
 * Core Project Access Request interface
 */
export interface IProjectAccessRequest {
  id: number
  user_id: number
  project_id: number
  created_at: string
  updated_at: string
  // Joined data
  user?: IUser
  project?: IProject
}

/**
 * Access request creation data
 */
export interface IAccessRequestCreate {
  project_id: number
}
