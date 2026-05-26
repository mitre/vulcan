import api from "./baseApi";

/** @param {number} componentId @returns {Promise} */
export function getComponent(componentId) {
  return api.get(`/components/${componentId}`);
}

/** @param {number} componentId @param {Object} data @returns {Promise} */
export function updateComponent(componentId, data) {
  return api.put(`/components/${componentId}`, { component: data });
}

/** @param {number} componentId @param {Object} data @returns {Promise} */
export function patchComponent(componentId, data) {
  return api.patch(`/components/${componentId}`, { component: data });
}

/** @param {number} componentId @returns {Promise} */
export function deleteComponent(componentId) {
  return api.delete(`/components/${componentId}`);
}

/** @param {number} projectId @param {Object|FormData} data @param {Object} [config] @returns {Promise} */
export function createComponentInProject(projectId, data, config = {}) {
  return api.post(`/projects/${projectId}/components`, data, config);
}

/** @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function detectSrg(formData, config = {}) {
  return api.post("/components/detect_srg", formData, config);
}

/** @param {number} componentId @param {Object} data @returns {Promise} */
export function lockComponent(componentId, data) {
  return api.post(`/components/${componentId}/lock`, { review: data });
}

/** @param {number} componentId @param {Object} data @returns {Promise} */
export function lockSections(componentId, data) {
  return api.patch(`/components/${componentId}/lock_sections`, data);
}

/** @param {number} componentId @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function previewSpreadsheetUpdate(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/preview_spreadsheet_update`, formData, config);
}

/** @param {number} componentId @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function applySpreadsheetUpdate(componentId, formData, config = {}) {
  return api.patch(`/components/${componentId}/apply_spreadsheet_update`, formData, config);
}

/** @param {number} componentId @param {Object} params @returns {Promise} */
export function getComments(componentId, params) {
  return api.get(`/components/${componentId}/comments`, { params });
}

/** @param {number} componentId @returns {Promise} */
export function getHistories(componentId) {
  return api.get(`/components/${componentId}/histories`);
}

/** @param {Object} data - { base_id, diff_id } @returns {Promise} */
export function getComponentHistory(data) {
  return api.post("/components/history", data);
}

/** @param {number} componentId @returns {Promise} */
export function searchBasedOnSameSrg(componentId) {
  return api.get(`/components/${componentId}/search/based_on_same_srg`);
}

/** @param {number} baseId @param {number} diffId @returns {Promise} */
export function compareComponents(baseId, diffId) {
  return api.get(`/components/${baseId}/compare/${diffId}`);
}

/** @returns {Promise} */
export function getComponents() {
  return api.get("/components");
}

/** @param {number} componentId @returns {Promise} */
export function getComponentRules(componentId) {
  return api.get(`/components/${componentId}/rules`);
}
