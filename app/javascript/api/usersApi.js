/**
 * User management and profile API.
 *
 * Admin operations (createUser, lockUser, etc.) require admin privileges.
 * Profile operations (updateProfile, deleteAccount, unlinkIdentity) act
 * on the currently signed-in user via Devise session.
 *
 * @module usersApi
 */
import api from "./baseApi";

/**
 * Typeahead user search. Uses `/api/` namespace for JSON-only endpoint.
 * @param {string} query - Search term (name or email substring).
 * @param {Object} [extraParams={}] - Additional filters (e.g. `{ project_id }`).
 */
export function searchUsers(query, extraParams = {}) {
  return api.get("/api/users/search", { params: { q: query, ...extraParams } });
}

/** Admin-only user creation (bypasses registration flow). */
export function createUser(userData) {
  return api.post("/users/admin_create", { user: userData });
}

export function updateUser(userId, userData) {
  return api.put(`/users/${userId}`, { user: userData });
}

export function deleteUser(userId) {
  return api.delete(`/users/${userId}`);
}

export function lockUser(userId) {
  return api.post(`/users/${userId}/lock`);
}

export function unlockUser(userId) {
  return api.post(`/users/${userId}/unlock`);
}

/** Sends Devise password reset email. Returns 422 if SMTP is disabled. */
export function sendPasswordReset(userId) {
  return api.post(`/users/${userId}/send_password_reset`);
}

/** Generate a one-time reset link (no email sent). Admin-only. */
export function generateResetLink(userId) {
  return api.post(`/users/${userId}/generate_reset_link`);
}

export function setPassword(userId, password, passwordConfirmation) {
  return api.post(`/users/${userId}/set_password`, {
    user: { password, password_confirmation: passwordConfirmation },
  });
}

/** Update the currently signed-in user's profile (no userId — Devise session). */
export function updateProfile(userData) {
  return api.put("/users", { user: userData });
}

/** Delete the currently signed-in user's account (no userId — Devise session). */
export function deleteAccount() {
  return api.delete("/users");
}

/**
 * Unlink an external identity (GitHub/LDAP/OIDC) from the current user.
 * Flat params — controller reads `params[:current_password]` directly,
 * not wrapped in `{ user: }`.
 * @param {Object} payload - `{ provider, current_password }`.
 */
export function unlinkIdentity(payload) {
  return api.post("/users/unlink_identity", payload);
}

export function getUserComments(userId, params) {
  return api.get(`/users/${userId}/comments`, { params });
}
