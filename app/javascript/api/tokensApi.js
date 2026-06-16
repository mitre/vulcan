/**
 * Personal Access Token (PAT) management API.
 *
 * Tokens use SHA-256 salted digest storage — the raw token is only available
 * once at creation time (returned in `data.raw_token`). The `vulcan_` prefix
 * makes tokens detectable by secret scanners (e.g. GitGuardian).
 *
 * @module tokensApi
 */
import api from "./baseApi";

export function listTokens() {
  return api.get("/personal_access_tokens");
}

/**
 * Create a new PAT. The response includes `raw_token` — this is the ONLY
 * time the full token value is available (show-once pattern).
 * @param {Object} data - `{ name, scopes, expires_at?, ip_allowlist? }`.
 * @returns {Promise<{data: {id, name, raw_token, token_prefix, ...}}>}
 */
export function createToken(data) {
  return api.post("/personal_access_tokens", { personal_access_token: data });
}

export function revokeToken(id) {
  return api.delete(`/personal_access_tokens/${id}`);
}

/**
 * Admin revoke another user's token. Uses DELETE with a request body for
 * the audit comment (same pattern as {@link module:reviewsApi.adminDestroyReview}).
 * @param {number} id - Token ID.
 * @param {string} auditComment - Required justification.
 */
export function adminRevokeToken(id, auditComment) {
  return api.delete(`/personal_access_tokens/${id}/admin_revoke`, {
    data: { audit_comment: auditComment },
  });
}

/** Admin: list tokens for a specific user. */
export function adminListTokens(userId) {
  return api.get(`/personal_access_tokens`, { params: { user_id: userId } });
}

/** Admin: create a token on behalf of another user. */
export function adminCreateToken(userId, data) {
  return api.post("/personal_access_tokens", {
    personal_access_token: { ...data, user_id: userId },
  });
}
