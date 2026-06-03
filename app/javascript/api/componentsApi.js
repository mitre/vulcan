/**
 * Component CRUD, locking, spreadsheet import, and comparison API.
 * @module componentsApi
 */
import api from "./baseApi";

export function getComponent(componentId) {
  return api.get(`/components/${componentId}`);
}

export function updateComponent(componentId, data) {
  return api.put(`/components/${componentId}`, { component: data });
}

/** Partial update — use for single-field changes (e.g. comment_period_ends_at). */
export function patchComponent(componentId, data) {
  return api.patch(`/components/${componentId}`, { component: data });
}

export function deleteComponent(componentId) {
  return api.delete(`/components/${componentId}`);
}

/**
 * Create a component in a project. Accepts JSON or FormData (for XCCDF upload).
 * When uploading XCCDF: payload is FormData with `file` and `srg_id` fields.
 * When creating empty: payload is `{ component: { title, srg_id, ... } }`.
 * @param {number} projectId
 * @param {FormData|Object} payload - FormData for XCCDF upload, Object for JSON.
 * @param {Object} [config={}] - Extra ky options.
 */
export function createComponentInProject(projectId, payload, config = {}) {
  return api.post(`/projects/${projectId}/components`, payload, config);
}

/**
 * Detect which SRG a DISA XCCDF file maps to before creating a component.
 * @param {FormData} formData - Must include the XCCDF XML file.
 * @returns {Promise<{data: {srg_id, srg_title, version}}>}
 */
export function detectSrg(formData, config = {}) {
  return api.post("/components/detect_srg", formData, config);
}

/**
 * Lock a component for final review. Wraps in `{ review: }` because the
 * lock request creates a review record (not a component update).
 */
export function lockComponent(componentId, data) {
  return api.post(`/components/${componentId}/lock`, { review: data });
}

export function lockSections(componentId, payload) {
  return api.patch(`/components/${componentId}/lock_sections`, payload);
}

/**
 * Upload a spreadsheet (CSV/XLSX) for a dry-run preview of what would change.
 * Returns diff summary without applying changes.
 * @param {number} componentId
 * @param {FormData} formData - Must include the spreadsheet file.
 */
export function previewSpreadsheetUpdate(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/preview_spreadsheet_update`, formData, config);
}

/**
 * Apply a previously previewed spreadsheet update. Server uses the same file
 * hash from the preview to ensure consistency.
 * @param {number} componentId
 * @param {FormData} formData - Same file as the preview step.
 */
export function applySpreadsheetUpdate(componentId, formData, config = {}) {
  return api.patch(`/components/${componentId}/apply_spreadsheet_update`, formData, config);
}

export function getComments(componentId, params) {
  return api.get(`/components/${componentId}/comments`, { params });
}

export function getHistories(componentId) {
  return api.get(`/components/${componentId}/histories`);
}

/**
 * Cross-component history comparison (diff view).
 * @param {Object} payload - `{ base_component_id, diff_component_id, ... }`.
 */
export function getComponentHistory(payload) {
  return api.get("/components/history", { params: payload });
}

/** Find other components based on the same SRG for cross-referencing. */
export function searchBasedOnSameSrg(componentId) {
  return api.get(`/components/${componentId}/related`);
}

/**
 * Compare two components rule-by-rule. Uses the `/api/` namespace for
 * the JSON-only API endpoint.
 * @param {number} baseId - Baseline component ID.
 * @param {number} diffId - Component to compare against.
 */
export function compareComponents(baseId, diffId) {
  return api.get("/api/components/compare", {
    params: { base_id: baseId, diff_id: diffId },
  });
}

export function getComponents() {
  return api.get("/components");
}

export function getComponentRules(componentId) {
  return api.get(`/components/${componentId}/rules`);
}
