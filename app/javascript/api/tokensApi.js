import api from "./baseApi";

export function listTokens() {
  return api.get("/personal_access_tokens");
}

export function createToken(data) {
  return api.post("/personal_access_tokens", { personal_access_token: data });
}

export function revokeToken(id) {
  return api.delete(`/personal_access_tokens/${id}`);
}

export function adminRevokeToken(id, auditComment) {
  return api.delete(`/personal_access_tokens/${id}/admin_revoke`, {
    data: { audit_comment: auditComment },
  });
}

export function adminListTokens(userId) {
  return api.get(`/personal_access_tokens`, { params: { user_id: userId } });
}

export function adminCreateToken(userId, data) {
  return api.post("/personal_access_tokens", {
    personal_access_token: { ...data, user_id: userId },
  });
}
