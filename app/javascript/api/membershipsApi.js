import api from "./baseApi";

export function createMembership(projectId, userId, role) {
  return api.post("/memberships.json", {
    membership: { project_id: projectId, user_id: userId, role },
  });
}

export function updateMembership(membershipId, role) {
  return api.put(`/memberships/${membershipId}.json`, { membership: { role } });
}

export function deleteMembership(membershipId) {
  return api.delete(`/memberships/${membershipId}.json`);
}

export function deleteAccessRequest(requestId) {
  return api.delete(`/project_access_requests/${requestId}.json`);
}
