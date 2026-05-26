import api from "./baseApi";

/** @returns {Promise} */
export function getProjects() {
  return api.get("/projects");
}

/** @param {number} projectId @returns {Promise} */
export function getProject(projectId) {
  return api.get(`/projects/${projectId}`);
}

/** @param {Object} projectData @returns {Promise} */
export function createProject(projectData) {
  return api.post("/projects", { project: projectData });
}

/** @param {number} projectId @returns {Promise} */
export function deleteProject(projectId) {
  return api.delete(`/projects/${projectId}`);
}

/** @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function createFromBackup(formData, config = {}) {
  return api.post("/projects/create_from_backup", formData, config);
}

/** @returns {Promise} */
export function getSrgs() {
  return api.get("/srgs");
}

/** @param {number} projectId @param {Object} data @returns {Promise} */
export function updateProject(projectId, data) {
  return api.put(`/projects/${projectId}`, { project: data });
}

/** @param {number} componentId @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function restoreBackup(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/import`, formData, config);
}

/** @param {number} projectId @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function importBackup(projectId, formData, config = {}) {
  return api.post(`/projects/${projectId}/import_backup`, formData, config);
}

/** @param {string} path @returns {Promise} */
export function getBenchmarkList(path) {
  return api.get(path);
}

/** @param {string} path @param {FormData} formData @param {Object} [config] @returns {Promise} */
export function uploadBenchmark(path, formData, config = {}) {
  return api.post(path, formData, config);
}

/** @param {string} path @returns {Promise} */
export function deleteBenchmark(path) {
  return api.delete(path);
}

/** @param {number} projectId @param {Object} params @returns {Promise} */
export function getProjectComments(projectId, params) {
  return api.get(`/projects/${projectId}/comments`, { params });
}

/** @param {number} projectId @param {string} type @param {Object} [options] @returns {Promise<string>} resolves to the export URL */
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

/** @param {string} type @param {number} benchmarkId @param {string} exportType @returns {Promise<string>} resolves to the export URL */
export function exportBenchmark(type, benchmarkId, exportType) {
  const url = `/${type}/${benchmarkId}/export/${exportType}`;
  return api.get(url).then(() => url);
}
