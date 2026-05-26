import api from "./baseApi";

export function createRuleReview(ruleId, data) {
  return api.post(`/rules/${ruleId}/reviews`, { review: data });
}

export function createComponentReview(componentId, data) {
  return api.post(`/components/${componentId}/reviews`, { review: data });
}

export function getResponses(reviewId, params) {
  return api.get(`/reviews/${reviewId}/responses`, { params });
}

/** @param {number} reviewId @param {string} section - XCCDF section key @param {string} auditComment - required audit trail note @returns {Promise} */
export function updateSection(reviewId, section, auditComment) {
  return api.patch(`/reviews/${reviewId}/section`, { section, audit_comment: auditComment });
}

export function reopenReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/reopen`);
}

export function getReactions(reviewId, params) {
  return api.get(`/reviews/${reviewId}/reactions`, { params });
}

export function getUserComments(userId, params) {
  return api.get(`/users/${userId}/comments`, { params });
}

export function triageReview(reviewId, payload) {
  return api.patch(`/reviews/${reviewId}/triage`, payload);
}

export function adjudicateReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/adjudicate`, {});
}

export function withdrawReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/withdraw`);
}

/** @param {number} reviewId @param {string} auditComment - server-enforced audit trail @returns {Promise} */
export function adminWithdrawReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_withdraw`, { audit_comment: auditComment });
}

export function adminRestoreReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_restore`, { audit_comment: auditComment });
}

/** @param {number} reviewId @param {number} ruleId - target rule to move thread to @param {string} auditComment @returns {Promise} */
export function moveReviewToRule(reviewId, ruleId, auditComment) {
  return api.patch(`/reviews/${reviewId}/move_to_rule`, {
    rule_id: ruleId,
    audit_comment: auditComment,
  });
}

/** @param {number} reviewId @param {string} auditComment - irreversible, requires typed confirmation @returns {Promise} */
export function adminDestroyReview(reviewId, auditComment) {
  return api.delete(`/reviews/${reviewId}/admin_destroy`, {
    data: { audit_comment: auditComment },
  });
}

/** @param {number} reviewId @param {'up'|'down'} kind @returns {Promise} */
export function toggleReaction(reviewId, kind) {
  return api.post(`/reviews/${reviewId}/reactions`, { kind });
}

export function updateReview(reviewId, data) {
  return api.put(`/reviews/${reviewId}`, { review: data });
}
