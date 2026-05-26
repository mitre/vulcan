import api from "./baseApi";

export function getProjects() {
  return api.get("/projects");
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

export function createFromBackup(formData, config = {}) {
  return api.post("/projects/create_from_backup", formData, config);
}

export function getSrgs() {
  return api.get("/srgs");
}

export function updateProject(projectId, data) {
  return api.put(`/projects/${projectId}`, { project: data });
}

export function restoreBackup(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/import`, formData, config);
}

export function importBackup(projectId, formData, config = {}) {
  return api.post(`/projects/${projectId}/import_backup`, formData, config);
}

export function getBenchmarkList(path) {
  return api.get(path);
}

export function uploadBenchmark(path, formData, config = {}) {
  return api.post(path, formData, config);
}

export function deleteBenchmark(path) {
  return api.delete(path);
}

export function getProjectComments(projectId, params) {
  return api.get(`/projects/${projectId}/comments`, { params });
}

export function exportProjectData(projectId, type, options = {}) {
  let url = `/projects/${projectId}/export/${type}?component_ids=${options.componentIds.join(",")}`;
  if (options.mode) url += `&mode=${options.mode}`;
  if (options.includeSrg) url += `&include_srg=true`;
  if (options.includeMemberships === false) url += `&include_memberships=false`;
  if (options.excludeSatisfiedBy) url += `&exclude_satisfied_by=true`;
  return api.get(url).then(() => url);
}
