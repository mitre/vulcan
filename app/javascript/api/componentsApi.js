import api from "./baseApi";

export function updateComponent(componentId, payload) {
  return api.put(`/components/${componentId}`, payload);
}

export function getComments(componentId, params) {
  return api.get(`/components/${componentId}/comments`, { params });
}
