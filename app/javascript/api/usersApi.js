import api from "./baseApi";

/** @param {string} query - min 2 chars @param {Object} [extraParams] - additional query params merged into request @returns {Promise} */
export function searchUsers(query, extraParams = {}) {
  return api.get("/api/users/search", { params: { q: query, ...extraParams } });
}

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

export function sendPasswordReset(userId) {
  return api.post(`/users/${userId}/send_password_reset`);
}

export function generateResetLink(userId) {
  return api.post(`/users/${userId}/generate_reset_link`);
}

/** @param {number} userId @param {string} password @param {string} passwordConfirmation - must match password @returns {Promise} */
export function setPassword(userId, password, passwordConfirmation) {
  return api.post(`/users/${userId}/set_password`, {
    user: { password, password_confirmation: passwordConfirmation },
  });
}

export function updateProfile(userData) {
  return api.put("/users", { user: userData });
}

export function deleteAccount() {
  return api.delete("/users");
}

/** @param {Object} payload - { current_password, provider } — flat, not wrapped @returns {Promise} */
export function unlinkIdentity(payload) {
  return api.post("/users/unlink_identity", payload);
}
