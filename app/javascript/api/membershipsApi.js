import api from "./baseApi";

export function createMembership(membershipData) {
  return api.post("/memberships", { membership: membershipData });
}

export function updateMembership(membershipId, role) {
  return api.put(`/memberships/${membershipId}`, { membership: { role } });
}

export function deleteMembership(membershipId) {
  return api.delete(`/memberships/${membershipId}`);
}

/** @param {number} projectId @param {number} requestId - ProjectAccessRequest ID @returns {Promise} */
export function deleteAccessRequest(projectId, requestId) {
  return api.delete(`/projects/${projectId}/project_access_requests/${requestId}`);
}
