/**
 * Component-related TypeScript interfaces
 */

import type { IProjectMembership } from './project'

/**
 * Rules summary counts for component cards
 */
export interface IRulesSummary {
  total: number
  primary_count: number
  nested_count: number
  locked: number
  under_review: number
  not_under_review: number
  changes_requested: number
  not_yet_determined: number
  applicable_configurable: number
  applicable_inherently_meets: number
  applicable_does_not_meet: number
  not_applicable: number
}

/**
 * Component metadata
 */
export interface IComponentMetadata {
  id: number
  component_id: number
  data: Record<string, string>
}

/**
 * Core Component interface matching Rails Component model
 */
export interface IComponent {
  id: number
  name: string
  prefix: string
  version: number
  release?: number
  title?: string
  description?: string
  released: boolean
  project_id: number
  component_id?: number | null // Parent component for overlays
  security_requirements_guide_id: number
  admin_name?: string
  admin_email?: string
  rules_count: number
  created_at: string
  updated_at: string
  // Computed fields from as_json
  based_on_title?: string
  based_on_version?: string
  releasable?: boolean
  rules_summary?: IRulesSummary
  parent_rules_count?: number
  primary_controls_count?: number
  // Relations
  memberships?: IProjectMembership[]
  component_metadata?: IComponentMetadata
}

/**
 * Component creation data
 */
export interface IComponentCreate {
  name: string
  prefix: string
  version?: number
  release?: number
  title?: string
  description?: string
  security_requirements_guide_id: number
  project_id: number
  component_id?: number // For overlays
}

/**
 * Component update data
 */
export interface IComponentUpdate {
  name?: string
  prefix?: string
  version?: number
  release?: number
  title?: string
  description?: string
  released?: boolean
  component_metadata_attributes?: {
    data: Record<string, string>
  }
}

/**
 * Component duplication options
 */
export interface IComponentDuplicate {
  new_name?: string
  new_prefix?: string
  new_version?: number
  new_release?: number
  new_title?: string
  new_description?: string
  new_project_id?: number
  new_srg_id?: number
}

/**
 * Components store state interface
 */
export interface IComponentsState {
  components: IComponent[]
  currentComponent: IComponent | null
  loading: boolean
  error: string | null
}
