import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  getComponent,
  updateComponent,
  patchComponent,
  deleteComponent,
  createComponentInProject,
  detectSrg,
  lockComponent,
  lockSections,
  previewSpreadsheetUpdate,
  applySpreadsheetUpdate,
  getComments,
  getHistories,
  getComponentHistory,
  searchBasedOnSameSrg,
  compareComponents,
  getComponents,
  getComponentRules,
} from "@/api/componentsApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("componentsApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("getComponent calls GET /components/:id", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getComponent(5);
    expect(api.get).toHaveBeenCalledWith("/components/5");
  });

  it("updateComponent wraps data in { component: data }", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateComponent(5, { name: "test" });
    expect(api.put).toHaveBeenCalledWith("/components/5", { component: { name: "test" } });
  });

  it("patchComponent wraps data in { component: data }", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await patchComponent(5, { advanced_fields: true });
    expect(api.patch).toHaveBeenCalledWith("/components/5", { component: { advanced_fields: true } });
  });

  it("deleteComponent calls DELETE /components/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteComponent(5);
    expect(api.delete).toHaveBeenCalledWith("/components/5");
  });

  it("createComponentInProject calls POST /projects/:id/components", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createComponentInProject(1, { name: "test" });
    expect(api.post).toHaveBeenCalledWith("/projects/1/components", { name: "test" }, {});
  });

  it("detectSrg calls POST /components/detect_srg", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await detectSrg(fd);
    expect(api.post).toHaveBeenCalledWith("/components/detect_srg", fd, {});
  });

  it("lockComponent wraps data in { review: data }", async () => {
    api.post.mockResolvedValue({ data: {} });
    await lockComponent(5, { action: "lock_control", comment: "Lock all" });
    expect(api.post).toHaveBeenCalledWith("/components/5/lock", {
      review: { action: "lock_control", comment: "Lock all" },
    });
  });

  it("lockSections calls PATCH /components/:id/lock_sections", async () => {
    api.patch.mockResolvedValue({ data: {} });
    await lockSections(5, { sections: ["Check"] });
    expect(api.patch).toHaveBeenCalledWith("/components/5/lock_sections", { sections: ["Check"] });
  });

  it("getComments calls GET /components/:id/comments", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getComments(5, { page: 1 });
    expect(api.get).toHaveBeenCalledWith("/components/5/comments", { params: { page: 1 } });
  });

  it("getHistories calls GET /components/:id/histories", async () => {
    api.get.mockResolvedValue({ data: {} });
    await getHistories(5);
    expect(api.get).toHaveBeenCalledWith("/components/5/histories");
  });

  it("searchBasedOnSameSrg calls GET /components/:id/search/based_on_same_srg", async () => {
    api.get.mockResolvedValue({ data: {} });
    await searchBasedOnSameSrg(5);
    expect(api.get).toHaveBeenCalledWith("/components/5/search/based_on_same_srg");
  });

  it("previewSpreadsheetUpdate calls POST /components/:id/preview_spreadsheet_update", async () => {
    api.post.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await previewSpreadsheetUpdate(5, fd);
    expect(api.post).toHaveBeenCalledWith("/components/5/preview_spreadsheet_update", fd, {});
  });

  it("applySpreadsheetUpdate calls PATCH /components/:id/apply_spreadsheet_update", async () => {
    api.patch.mockResolvedValue({ data: {} });
    const fd = new FormData();
    await applySpreadsheetUpdate(5, fd);
    expect(api.patch).toHaveBeenCalledWith("/components/5/apply_spreadsheet_update", fd, {});
  });

  it("getComponentHistory calls POST /components/history", async () => {
    api.post.mockResolvedValue({ data: {} });
    await getComponentHistory({ component_id: 5 });
    expect(api.post).toHaveBeenCalledWith("/components/history", { component_id: 5 });
  });

  it("compareComponents calls GET /components/:base/compare/:diff", async () => {
    api.get.mockResolvedValue({ data: {} });
    await compareComponents(5, 10);
    expect(api.get).toHaveBeenCalledWith("/components/5/compare/10");
  });

  it("getComponents calls GET /components", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getComponents();
    expect(api.get).toHaveBeenCalledWith("/components");
  });

  it("getComponentRules calls GET /components/:id/rules", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getComponentRules(5);
    expect(api.get).toHaveBeenCalledWith("/components/5/rules");
  });

  describe("error propagation", () => {
    it("updateComponent propagates rejected promise", async () => {
      api.put.mockRejectedValue(new Error("403 Forbidden"));
      await expect(updateComponent(5, { name: "x" })).rejects.toThrow("403 Forbidden");
    });
  });

  describe("edge cases", () => {
    it("getComponent sends undefined id in URL without error", async () => {
      api.get.mockResolvedValue({ data: null });
      await getComponent(undefined);
      expect(api.get).toHaveBeenCalledWith("/components/undefined");
    });

    it("updateComponent wraps empty object in component key", async () => {
      api.put.mockResolvedValue({ data: {} });
      await updateComponent(1, {});
      expect(api.put).toHaveBeenCalledWith("/components/1", { component: {} });
    });

    it("getComments passes empty params object", async () => {
      api.get.mockResolvedValue({ data: {} });
      await getComments(1, {});
      expect(api.get).toHaveBeenCalledWith("/components/1/comments", { params: {} });
    });
  });
});
