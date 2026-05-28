import {
  triageReview,
  bulkTriageReviews,
  adjudicateReview,
  adminDestroyReview,
  moveReviewToRule,
  adminWithdrawReview,
  adminRestoreReview,
} from "../api/reviewsApi";

export function submitTriage(reviewId, payload) {
  return triageReview(reviewId, payload);
}

export function submitBulkTriage(reviewIds, payload) {
  return bulkTriageReviews(reviewIds, payload);
}

export function submitAdjudicate(reviewId) {
  return adjudicateReview(reviewId);
}

export function submitAdminAction(reviewId, action, params) {
  if (action === "hard-delete") {
    return adminDestroyReview(reviewId, params.audit_comment);
  }
  if (action === "move-to-rule") {
    return moveReviewToRule(reviewId, params.rule_id, params.audit_comment);
  }
  if (action === "force-withdraw") {
    return adminWithdrawReview(reviewId, params.audit_comment);
  }
  if (action === "restore") {
    return adminRestoreReview(reviewId, params.audit_comment);
  }
  return Promise.reject(new Error(`Unknown admin action: ${action}`));
}
