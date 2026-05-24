import axios from "axios";

export function submitTriage(reviewId, payload) {
  return axios.patch(`/reviews/${reviewId}/triage`, payload);
}

export function submitAdjudicate(reviewId) {
  return axios.patch(`/reviews/${reviewId}/adjudicate`, {});
}

export function submitAdminAction(reviewId, action, params) {
  if (action === "hard-delete") {
    return axios.delete(`/reviews/${reviewId}/admin_destroy`, {
      data: { audit_comment: params.audit_comment },
    });
  }
  if (action === "move-to-rule") {
    return axios.patch(`/reviews/${reviewId}/move_to_rule`, {
      rule_id: params.rule_id,
      audit_comment: params.audit_comment,
    });
  }
  if (action === "force-withdraw") {
    return axios.patch(`/reviews/${reviewId}/admin_withdraw`, {
      audit_comment: params.audit_comment,
    });
  }
  if (action === "restore") {
    return axios.patch(`/reviews/${reviewId}/admin_restore`, {
      audit_comment: params.audit_comment,
    });
  }
  return Promise.reject(new Error(`Unknown admin action: ${action}`));
}
