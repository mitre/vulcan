import api from "./baseApi";

export function getComponent(componentId) {
  return api.get(`/components/${componentId}`);
}

export function updateComponent(componentId, data) {
  return api.put(`/components/${componentId}`, { component: data });
}

export function patchComponent(componentId, data) {
  return api.patch(`/components/${componentId}`, { component: data });
}

export function deleteComponent(componentId) {
  return api.delete(`/components/${componentId}`);
}

export function createComponentInProject(projectId, payload, config = {}) {
  return api.post(`/projects/${projectId}/components`, payload, config);
}

export function detectSrg(formData, config = {}) {
  return api.post("/components/detect_srg", formData, config);
}

export function lockComponent(componentId, data) {
  return api.post(`/components/${componentId}/lock`, { review: data });
}

export function lockSections(componentId, payload) {
  return api.patch(`/components/${componentId}/lock_sections`, payload);
}

export function previewSpreadsheetUpdate(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/preview_spreadsheet_update`, formData, config);
}

export function applySpreadsheetUpdate(componentId, formData, config = {}) {
  return api.patch(`/components/${componentId}/apply_spreadsheet_update`, formData, config);
}

export function getComments(componentId, params) {
  return api.get(`/components/${componentId}/comments`, { params });
}

export function getHistories(componentId) {
  return api.get(`/components/${componentId}/histories`);
}

export function getComponentHistory(payload) {
  return api.post("/components/history", payload);
}

// vulcan-v3.x-aik: renamed from /search/based_on_same_srg for clarity.
export function searchBasedOnSameSrg(componentId) {
  return api.get(`/components/${componentId}/related`);
}

export function compareComponents(baseId, diffId) {
  return api.get(`/components/${baseId}/compare/${diffId}`);
}

export function getComponents() {
  return api.get("/components");
}

export function getComponentRules(componentId) {
  return api.get(`/components/${componentId}/rules`);
}
