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
  return api.delete(`/projects/${projectId}.json`);
}

export function createFromBackup(formData, config = {}) {
  return api.post("/projects/create_from_backup", formData, config);
}

export function getSrgs() {
  return api.get("/srgs");
}

export function restoreBackup(componentId, formData, config = {}) {
  return api.post(`/components/${componentId}/import`, formData, config);
}
