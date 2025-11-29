/**
 * Rules API
 * Rule CRUD and related operations
 */

import type { IRule, ISlimRule, IRuleUpdate, IReviewCreate, IPaginatedRulesResponse } from '@/types'
import { http } from '@/services/http.service'

/**
 * Pagination parameters
 */
export interface PaginationParams {
  page?: number
  per_page?: number
}

/**
 * Get all rules for a component (slim data for list view)
 * GET /components/:componentId/rules
 * Supports optional pagination via page/per_page params
 */
export function getComponentRules(componentId: number, params?: PaginationParams) {
  if (params?.page) {
    // Paginated request
    return http.get<IPaginatedRulesResponse>(`/components/${componentId}/rules`, { params })
  }
  // Non-paginated (backwards compatible)
  return http.get<ISlimRule[]>(`/components/${componentId}/rules`)
}

/**
 * Get a single rule by ID (full data for detail view)
 * GET /rules/:id
 * Returns complete rule data via RuleBlueprint including associations
 */
export function getRule(id: number) {
  return http.get<IRule>(`/rules/${id}`)
}

/**
 * Create a new rule
 * POST /components/:componentId/rules
 */
export function createRule(componentId: number, data: Partial<IRule>) {
  return http.post<IRule>(`/components/${componentId}/rules`, { rule: data })
}

/**
 * Response from rule update endpoint
 */
export interface IRuleUpdateResponse {
  toast: string
  rule: IRule
}

/**
 * Update a rule
 * PATCH /rules/:id
 * Returns full rule data for cache update
 */
export function updateRule(id: number, data: IRuleUpdate) {
  return http.patch<IRuleUpdateResponse>(`/rules/${id}`, { rule: data })
}

/**
 * Delete a rule (soft delete)
 * DELETE /rules/:id
 */
export function deleteRule(id: number) {
  return http.delete(`/rules/${id}`)
}

/**
 * Revert a rule to a historical version
 * POST /rules/:id/revert
 */
export function revertRule(
  id: number,
  auditId: number,
  fields: string[],
  auditComment?: string
) {
  return http.post(`/rules/${id}/revert`, {
    audit_id: auditId,
    fields,
    audit_comment: auditComment,
  })
}

/**
 * Create a rule satisfaction (merge relationship)
 * POST /rule_satisfactions
 */
export function createRuleSatisfaction(ruleId: number, satisfiedByRuleId: number) {
  return http.post('/rule_satisfactions', {
    rule_id: ruleId,
    satisfied_by_rule_id: satisfiedByRuleId,
  })
}

/**
 * Remove a rule satisfaction (unmerge)
 * DELETE /rule_satisfactions/:id
 */
export function deleteRuleSatisfaction(ruleId: number, satisfiedByRuleId: number) {
  return http.delete(`/rule_satisfactions/${ruleId}`, {
    data: {
      rule_id: ruleId,
      satisfied_by_rule_id: satisfiedByRuleId,
    },
  })
}

/**
 * Create a review action on a rule
 * POST /rules/:id/reviews
 *
 * Review actions include:
 * - 'request_review' - Request review (locks editing)
 * - 'revoke_review_request' - Cancel review request
 * - 'request_changes' - Reviewer requests changes
 * - 'approve' - Approve and lock the rule
 * - 'lock_control' - Admin directly locks (skips review)
 * - 'unlock_control' - Admin unlocks a locked rule
 * - 'comment' - Add a comment without status change
 */
export function createReview(ruleId: number, data: IReviewCreate) {
  return http.post(`/rules/${ruleId}/reviews`, { review: data })
}
