/**
 * Review lifecycle and triage API.
 *
 * Reviews follow a lifecycle: open → triage (concur/non_concur/informational/
 * duplicate/addressed_by) → adjudicate → closed. Lifecycle actions use flat
 * params (no `{ review: }` wrapper). CRUD mutations wrap in `{ review: }`.
 *
 * @module reviewsApi
 */
import api from "./baseApi";

export function createRuleReview(ruleId, data) {
  return api.post(`/rules/${ruleId}/reviews`, { review: data });
}

/**
 * Post an overall/null-section comment on a component (not tied to a specific rule).
 * @param {number} componentId
 * @param {Object} data - Review fields (comment, section, etc.).
 */
export function createComponentReview(componentId, data) {
  return api.post(`/components/${componentId}/reviews`, { review: data });
}

export function getReviewResponses(reviewId, params) {
  return api.get(`/reviews/${reviewId}/responses`, { params });
}

/**
 * Update a single section (check_content, fix_text, etc.) with an audit trail entry.
 * Flat params — not wrapped in `{ review: }` because this is a targeted field edit.
 * @param {number} reviewId
 * @param {string} section - Section identifier (e.g. "check_content", "fix_text").
 * @param {string} auditComment - Required audit trail justification.
 */
export function updateReviewSection(reviewId, section, auditComment) {
  return api.patch(`/reviews/${reviewId}/section`, { section, audit_comment: auditComment });
}

export function reopenReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/reopen`);
}

export function getReviewReactions(reviewId, params) {
  return api.get(`/reviews/${reviewId}/reactions`, { params });
}

/**
 * Set triage status on a review. Flat params (lifecycle action convention).
 * @param {number} reviewId
 * @param {Object} payload - `{ triage_status, duplicate_of_review_id?, audit_comment? }`.
 */
export function triageReview(reviewId, payload) {
  return api.patch(`/reviews/${reviewId}/triage`, payload);
}

/**
 * Triage multiple reviews at once. Payload is spread alongside review_ids —
 * flat params, not wrapped in `{ review: }` (lifecycle action convention).
 * @param {number[]} reviewIds - Array of review IDs to triage.
 * @param {Object} payload - `{ triage_status, audit_comment? }`.
 */
export function bulkTriageReviews(reviewIds, payload) {
  return api.patch("/reviews/bulk_triage", { review_ids: reviewIds, ...payload });
}

/**
 * Merge duplicate reviews into a single survivor. All non-survivor reviews
 * are marked as duplicates pointing to the survivor.
 * @param {number[]} reviewIds - All review IDs to merge (including survivor).
 * @param {number} survivorId - The review that absorbs the others.
 */
export function mergeReviews(reviewIds, survivorId) {
  return api.patch("/reviews/merge", { review_ids: reviewIds, survivor_id: survivorId });
}

/** Close a review after triage is complete. Requires all triage decisions finalized. */
export function adjudicateReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/adjudicate`, {});
}

export function withdrawReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/withdraw`);
}

/**
 * Admin force-withdraw — bypasses frozen_for_writes check. Requires audit comment.
 * @param {number} reviewId
 * @param {string} auditComment - Required justification (server-enforced 422 if missing).
 */
export function adminWithdrawReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_withdraw`, { audit_comment: auditComment });
}

/**
 * Admin restore a withdrawn review. Requires audit comment.
 * @param {number} reviewId
 * @param {string} auditComment - Required justification (server-enforced 422 if missing).
 */
export function adminRestoreReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_restore`, { audit_comment: auditComment });
}

/**
 * Move a review (and its reply tree) to a different rule. Parent-first walk
 * on the server to satisfy the responding_to_must_be_same_rule validator.
 * @param {number} reviewId
 * @param {number} ruleId - Destination rule.
 * @param {string} auditComment - Required justification.
 */
export function moveReviewToRule(reviewId, ruleId, auditComment) {
  return api.patch(`/reviews/${reviewId}/move_to_rule`, {
    rule_id: ruleId,
    audit_comment: auditComment,
  });
}

/**
 * Permanently delete a review. Uses DELETE with a request body — ky sends
 * the body via `{ json: }` which the `api.delete` wrapper translates from
 * `{ data: }` for backwards compatibility with the axios-era call sites.
 * @param {number} reviewId
 * @param {string} auditComment - Required justification.
 */
export function adminDestroyReview(reviewId, auditComment) {
  return api.delete(`/reviews/${reviewId}/admin_destroy`, {
    data: { audit_comment: auditComment },
  });
}

/** Toggle a reaction (like/dislike). Idempotent — second call removes it. */
export function toggleReaction(reviewId, kind) {
  return api.post(`/reviews/${reviewId}/reactions`, { kind });
}

export function updateReview(reviewId, data) {
  return api.put(`/reviews/${reviewId}`, { review: data });
}
