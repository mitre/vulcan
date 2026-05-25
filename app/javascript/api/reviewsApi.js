import api from "./baseApi";

export function createReview(url, payload) {
  return api.post(url, payload);
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
