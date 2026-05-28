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

export function bulkTriageReviews(reviewIds, payload) {
  return api.patch("/reviews/bulk_triage", { review_ids: reviewIds, ...payload });
}

export function adjudicateReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/adjudicate`, {});
}

export function withdrawReview(reviewId) {
  return api.patch(`/reviews/${reviewId}/withdraw`);
}

export function adminWithdrawReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_withdraw`, { audit_comment: auditComment });
}

export function adminRestoreReview(reviewId, auditComment) {
  return api.patch(`/reviews/${reviewId}/admin_restore`, { audit_comment: auditComment });
}

export function moveReviewToRule(reviewId, ruleId, auditComment) {
  return api.patch(`/reviews/${reviewId}/move_to_rule`, {
    rule_id: ruleId,
    audit_comment: auditComment,
  });
}

export function adminDestroyReview(reviewId, auditComment) {
  return api.delete(`/reviews/${reviewId}/admin_destroy`, {
    data: { audit_comment: auditComment },
  });
}

export function toggleReaction(reviewId, kind) {
  return api.post(`/reviews/${reviewId}/reactions`, { kind });
}

export function updateReview(reviewId, data) {
  return api.put(`/reviews/${reviewId}`, { review: data });
}
