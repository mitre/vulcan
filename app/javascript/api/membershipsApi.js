import api from "./baseApi";

export function createMembership(membershipData) {
  return api.post("/memberships.json", { membership: membershipData });
}

export function updateMembership(membershipId, role) {
  return api.put(`/memberships/${membershipId}.json`, { membership: { role } });
}

export function deleteMembership(membershipId) {
  return api.delete(`/memberships/${membershipId}.json`);
}

export function deleteAccessRequest(projectId, requestId) {
  return api.delete(`/projects/${projectId}/project_access_requests/${requestId}.json`);
}
