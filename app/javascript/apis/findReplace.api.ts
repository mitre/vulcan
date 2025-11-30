/**
 * Find & Replace API
 * API client for find and replace operations within components
 *
 * Architecture: This is Layer 2 (API Client) - pure HTTP calls, no state.
 * See docs-spa/FIND-REPLACE-ARCHITECTURE.md for full architecture.
 */

import type { IRule } from '@/types'
import { http } from '@/services/http.service'

// ============================================================================
// Request Interfaces
// ============================================================================

/**
 * Parameters for finding matches
 */
export interface FindParams {
  search: string
  caseSensitive?: boolean
  fields?: string[]
}

/**
 * Parameters for replacing a single instance
 */
export interface ReplaceInstanceParams {
  search: string
  ruleId: number
  field: string
  instanceIndex: number
  replacement: string
  caseSensitive?: boolean
  auditComment?: string
}

/**
 * Parameters for replacing all instances in a field
 */
export interface ReplaceFieldParams {
  search: string
  ruleId: number
  field: string
  replacement: string
  caseSensitive?: boolean
  auditComment?: string
}

/**
 * Parameters for replacing all matches
 */
export interface ReplaceAllParams {
  search: string
  replacement: string
  caseSensitive?: boolean
  fields?: string[]
  auditComment?: string
}

// ============================================================================
// Response Interfaces
// ============================================================================

/**
 * A single match instance within a field
 */
export interface MatchInstance {
  index: number
  length: number
  text: string
  context: string
  instance_index?: number
}

/**
 * Matches within a field
 */
export interface FieldMatch {
  field: string
  instances: MatchInstance[]
}

/**
 * Matches within a rule
 */
export interface RuleMatch {
  rule_id: number
  rule_identifier: string
  match_count: number
  instances: FieldMatch[]
}

/**
 * Response from the find endpoint
 */
export interface FindResponse {
  total_matches: number
  total_rules: number
  matches: RuleMatch[]
}

/**
 * Response from replace endpoints (instance, field)
 */
export interface ReplaceResponse {
  success: boolean
  rule?: IRule
  error?: string
  replaced_count?: number
}

/**
 * Response from replace all endpoint
 */
export interface ReplaceAllResponse {
  success: boolean
  rules_updated: number
  matches_replaced: number
  error?: string
}

/**
 * Response from undo endpoint
 */
export interface UndoResponse {
  success: boolean
  rule?: IRule
  reverted_fields?: string[]
  error?: string
}

// ============================================================================
// API Functions
// ============================================================================

/**
 * Find all matches in a component
 * POST /api/components/:componentId/find_replace/find
 *
 * @param componentId - The component to search within
 * @param params - Search parameters
 * @returns Promise with find results including all matches with positions and context
 */
export async function find(componentId: number, params: FindParams): Promise<FindResponse> {
  const response = await http.post<FindResponse>(
    `/api/components/${componentId}/find_replace/find`,
    {
      search: params.search,
      case_sensitive: params.caseSensitive ?? false,
      fields: params.fields,
    },
  )
  return response.data
}

/**
 * Replace a single instance of a match
 * POST /api/components/:componentId/find_replace/replace_instance
 *
 * @param componentId - The component containing the rule
 * @param params - Replace parameters including exact position
 * @returns Promise with updated rule or error
 */
export async function replaceInstance(
  componentId: number,
  params: ReplaceInstanceParams,
): Promise<ReplaceResponse> {
  const response = await http.post<ReplaceResponse>(
    `/api/components/${componentId}/find_replace/replace_instance`,
    {
      search: params.search,
      rule_id: params.ruleId,
      field: params.field,
      instance_index: params.instanceIndex,
      replacement: params.replacement,
      case_sensitive: params.caseSensitive ?? false,
      audit_comment: params.auditComment,
    },
  )
  return response.data
}

/**
 * Replace all instances within a single field of a rule
 * POST /api/components/:componentId/find_replace/replace_field
 *
 * @param componentId - The component containing the rule
 * @param params - Replace parameters
 * @returns Promise with updated rule and count of replacements
 */
export async function replaceField(
  componentId: number,
  params: ReplaceFieldParams,
): Promise<ReplaceResponse> {
  const response = await http.post<ReplaceResponse>(
    `/api/components/${componentId}/find_replace/replace_field`,
    {
      search: params.search,
      rule_id: params.ruleId,
      field: params.field,
      replacement: params.replacement,
      case_sensitive: params.caseSensitive ?? false,
      audit_comment: params.auditComment,
    },
  )
  return response.data
}

/**
 * Replace all matches across all rules in the component
 * POST /api/components/:componentId/find_replace/replace_all
 *
 * @param componentId - The component to update
 * @param params - Replace parameters
 * @returns Promise with count of rules updated and matches replaced
 */
export async function replaceAll(
  componentId: number,
  params: ReplaceAllParams,
): Promise<ReplaceAllResponse> {
  const response = await http.post<ReplaceAllResponse>(
    `/api/components/${componentId}/find_replace/replace_all`,
    {
      search: params.search,
      replacement: params.replacement,
      case_sensitive: params.caseSensitive ?? false,
      fields: params.fields,
      audit_comment: params.auditComment,
    },
  )
  return response.data
}

/**
 * Undo the last Find & Replace operation on a rule
 * POST /api/components/:componentId/find_replace/undo
 *
 * Uses the audited gem to find and revert the most recent Find & Replace change.
 *
 * @param componentId - The component containing the rule
 * @param ruleId - The rule to undo changes on
 * @returns Promise with reverted rule and list of reverted fields
 */
export async function undo(componentId: number, ruleId: number): Promise<UndoResponse> {
  const response = await http.post<UndoResponse>(
    `/api/components/${componentId}/find_replace/undo`,
    {
      rule_id: ruleId,
    },
  )
  return response.data
}
