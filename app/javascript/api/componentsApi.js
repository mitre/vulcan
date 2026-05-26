import api from "./baseApi";

export function getComponent(componentId) {
  return api.get(`/components/${componentId}.json`);
}

export function updateComponent(componentId, payload) {
  return api.put(`/components/${componentId}`, payload);
}

export function patchComponent(componentId, payload) {
  return api.patch(`/components/${componentId}`, payload);
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

export function lockComponent(componentId, payload) {
  return api.post(`/components/${componentId}/lock`, payload);
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

export function searchBasedOnSameSrg(componentId) {
  return api.get(`/components/${componentId}/search/based_on_same_srg`);
}

export function compareComponents(baseId, diffId) {
  return api.get(`/components/${baseId}/compare/${diffId}`);
}
