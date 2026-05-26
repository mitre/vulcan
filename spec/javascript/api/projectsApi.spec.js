import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  getProjects,
  getProject,
  createProject,
  deleteProject,
  updateProject,
  createFromBackup,
  getSrgs,
  restoreBackup,
  importBackup,
  getBenchmarkList,
  uploadBenchmark,
  deleteBenchmark,
  getProjectComments,
  exportProjectData,
} from "@/api/projectsApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("projectsApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("getProjects calls GET /projects", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getProjects();
    expect(api.get).toHaveBeenCalledWith("/projects");
  });

  it("getProject calls GET /projects/:id", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getProject(5);
    expect(api.get).toHaveBeenCalledWith("/projects/5");
  });

  it("createProject calls POST /projects", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createProject({ name: "Test" });
    expect(api.post).toHaveBeenCalledWith("/projects", { project: { name: "Test" } });
  });

  it("deleteProject calls DELETE /projects/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteProject(5);
    expect(api.delete).toHaveBeenCalledWith("/projects/5");
  });

  it("updateProject wraps data in { project: data }", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateProject(5, { name: "Updated" });
    expect(api.put).toHaveBeenCalledWith("/projects/5", { project: { name: "Updated" } });
  });

  it("getSrgs calls GET /srgs", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getSrgs();
    expect(api.get).toHaveBeenCalledWith("/srgs");
  });

  it("importBackup calls POST /projects/:id/import_backup", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await importBackup(5, fd);
    expect(api.post).toHaveBeenCalledWith("/projects/5/import_backup", fd, {});
  });

  it("createFromBackup calls POST /projects/create_from_backup", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await createFromBackup(fd);
    expect(api.post).toHaveBeenCalledWith("/projects/create_from_backup", fd, {});
  });

  it("restoreBackup calls POST /components/:id/import", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await restoreBackup(5, fd);
    expect(api.post).toHaveBeenCalledWith("/components/5/import", fd, {});
  });

  it("uploadBenchmark calls POST with provided path and formData", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await uploadBenchmark("/stigs", fd);
    expect(api.post).toHaveBeenCalledWith("/stigs", fd, {});
  });

  it("getBenchmarkList calls GET with provided path", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getBenchmarkList("/srgs");
    expect(api.get).toHaveBeenCalledWith("/srgs");
  });

  it("deleteBenchmark calls DELETE with provided path", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteBenchmark("/stigs/5.json");
    expect(api.delete).toHaveBeenCalledWith("/stigs/5.json");
  });

  it("getProjectComments calls GET /projects/:id/comments with params", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getProjectComments(3, { page: 1, status: "pending" });
    expect(api.get).toHaveBeenCalledWith("/projects/3/comments", { params: { page: 1, status: "pending" } });
  });

  describe("exportProjectData", () => {
    it("builds URL with all params, calls GET, and resolves to URL", async () => {
      api.get.mockResolvedValue({ data: {} });
      const expectedUrl =
        "/projects/1/export/csv?component_ids=10,20&mode=working_copy&include_srg=true&include_memberships=false&exclude_satisfied_by=true";

      const url = await exportProjectData(1, "csv", {
        componentIds: [10, 20],
        mode: "working_copy",
        includeSrg: true,
        includeMemberships: false,
        excludeSatisfiedBy: true,
      });

      expect(api.get).toHaveBeenCalledWith(expectedUrl);
      expect(url).toBe(expectedUrl);
    });

    it("builds URL with only required params", async () => {
      api.get.mockResolvedValue({ data: {} });
      const url = await exportProjectData(5, "xccdf", { componentIds: [3] });

      expect(api.get).toHaveBeenCalledWith("/projects/5/export/xccdf?component_ids=3");
      expect(url).toBe("/projects/5/export/xccdf?component_ids=3");
    });
  });
});
