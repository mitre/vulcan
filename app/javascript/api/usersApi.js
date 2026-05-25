import api from "./baseApi";

export function searchUsers(query) {
  return api.get("/api/users/search", { params: { q: query } });
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

export function unlinkIdentity(provider) {
  return api.post("/users/unlink_identity", { provider });
}
