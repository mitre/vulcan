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

/**
 * Admin: list tokens for a specific user (metadata only — never the secret).
 *
 * Admin oversight of someone else's tokens is READ and REVOKE only. There is
 * deliberately no admin create-on-behalf helper: a token authenticates AS its
 * owner, so minting one for another user would make every audit record
 * attributed to them repudiable. Account recovery goes through a password
 * reset, where the user re-authenticates and the admin never holds a
 * credential that speaks as them.
 */
export function adminListTokens(userId) {
  return api.get(`/personal_access_tokens`, { params: { user_id: userId } });
}
