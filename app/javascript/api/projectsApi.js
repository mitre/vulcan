/**
 * Project management and export API.
 * @module projectsApi
 */
import api from "./baseApi";

export function getProjects() {
  return api.get("/projects");
}

export function getTriageResponseTemplates(projectId) {
  return api.get(`/projects/${projectId}/triage_response_templates`);
}

export function getProject(projectId) {
  return api.get(`/projects/${projectId}`);
}

export function createProject(projectData) {
  return api.post("/projects", { project: projectData });
}

export function deleteProject(projectId) {
  return api.delete(`/projects/${projectId}`);
}

/**
 * Create a new project from a JSON archive (.zip) backup.
 * Supports dry_run mode (preview) and full create. FormData — do NOT set
 * Content-Type manually (ky auto-sets multipart boundary).
 * @param {FormData} formData - Must include `file` and optionally `dry_run`,
 *   `project_name`, `project_description`, `project_visibility`.
 * @param {Object} [config={}] - Extra ky options.
 * @returns {Promise<{data: {summary, warnings, project_defaults?, redirect_url?}}>}
 */
export function createFromBackup(formData, config = {}) {
  return api.post("/projects/create_from_backup", formData, config);
}

export function getSrgs() {
  return api.get("/srgs");
}

export function updateProject(projectId, data) {
  return api.put(`/projects/${projectId}`, { project: data });
}

/**
 * Import a JSON archive backup into an existing project. Same endpoint as
 * {@link restoreBackup} — both names kept for semantic clarity at call sites.
 * @param {number} projectId
 * @param {FormData} formData - Must include `file`.
 * @param {Object} [config={}] - Extra ky options.
 */
export function importBackup(projectId, formData, config = {}) {
  return api.post(`/projects/${projectId}/import_backup`, formData, config);
}

/**
 * Alias for {@link importBackup}. "Restore" reads better in the UI when
 * the intent is restoring a component from an archive backup.
 */
export const restoreBackup = importBackup;

/**
 * Generic benchmark list fetcher. Path is dynamic because the same component
 * renders SRGs, STIGs, and project components with different API routes.
 * @param {string} path - API path (e.g. "/srgs", "/stigs", "/components").
 */
export function getBenchmarkList(path) {
  return api.get(path);
}

/**
 * Upload a benchmark file (SRG/STIG XML). Path is dynamic — same component
 * handles uploads for multiple resource types.
 * @param {string} path - API path (e.g. "/srgs", "/stigs").
 * @param {FormData} formData - Must include the XML file.
 * @param {Object} [config={}] - Extra ky options.
 */
export function uploadBenchmark(path, formData, config = {}) {
  return api.post(path, formData, config);
}

export function deleteBenchmark(path) {
  return api.delete(path);
}

export function getProjectComments(projectId, params) {
  return api.get(`/projects/${projectId}/comments`, { params });
}

/**
 * Trigger a project data export and return the download URL — NOT the file
 * contents. The GET request initiates the export on the server; the resolved
 * URL is then used for `window.location.href` to trigger the browser download.
 *
 * @param {number} projectId
 * @param {string} type - Export format: "json", "csv", "xccdf", "inspec".
 * @param {Object} options
 * @param {number[]} options.componentIds - Component IDs to include (required).
 * @param {string} [options.mode] - Export mode (e.g. "working_copy", "published").
 * @param {boolean} [options.includeSrg] - Include SRG baseline data.
 * @param {boolean} [options.includeMemberships] - Include project memberships (default true).
 * @param {boolean} [options.excludeSatisfiedBy] - Exclude satisfied-by relationships.
 * @returns {Promise<string>} The download URL (not the response data).
 */
export function exportProjectData(projectId, type, options = {}) {
  const params = new URLSearchParams();
  params.set("component_ids", options.componentIds.join(","));
  if (options.mode) params.set("mode", options.mode);
  if (options.includeSrg) params.set("include_srg", "true");
  if (options.includeMemberships === false) params.set("include_memberships", "false");
  if (options.excludeSatisfiedBy) params.set("exclude_satisfied_by", "true");
  const url = `/projects/${projectId}/export/${type}?${params.toString()}`;
  return api.get(url).then(() => url);
}

/**
 * Export a published benchmark (SRG/STIG). Returns the download URL, not
 * file contents — same pattern as {@link exportProjectData}.
 * @param {string} type - Resource type path segment ("srgs" or "stigs").
 * @param {number} benchmarkId
 * @param {string} exportType - Export format ("xccdf", "csv", etc.).
 * @returns {Promise<string>} The download URL.
 */
export function exportBenchmark(type, benchmarkId, exportType) {
  const url = `/${type}/${benchmarkId}/export/${exportType}`;
  return api.get(url).then(() => url);
}
