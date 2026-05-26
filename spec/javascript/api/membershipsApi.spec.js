import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  createMembership,
  updateMembership,
  deleteMembership,
  deleteAccessRequest,
} from "@/api/membershipsApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn() },
}));

describe("membershipsApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("createMembership posts to /memberships with membership data", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createMembership({ project_id: 1, user_id: 2, role: "viewer" });
    expect(api.post).toHaveBeenCalledWith("/memberships", {
      membership: { project_id: 1, user_id: 2, role: "viewer" },
    });
  });

  it("createMembership supports component memberships", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createMembership({ user_id: 5, role: "author", membership_type: "Component", membership_id: 10 });
    expect(api.post).toHaveBeenCalledWith("/memberships", {
      membership: { user_id: 5, role: "author", membership_type: "Component", membership_id: 10 },
    });
  });

  it("updateMembership puts to /memberships/:id", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateMembership(5, "admin");
    expect(api.put).toHaveBeenCalledWith("/memberships/5", {
      membership: { role: "admin" },
    });
  });

  it("deleteMembership deletes /memberships/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteMembership(5);
    expect(api.delete).toHaveBeenCalledWith("/memberships/5");
  });

  it("deleteAccessRequest deletes nested /projects/:projectId/project_access_requests/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteAccessRequest(10, 3);
    expect(api.delete).toHaveBeenCalledWith("/projects/10/project_access_requests/3");
  });

  describe("error propagation", () => {
    it("createMembership propagates rejected promise", async () => {
      api.post.mockRejectedValue(new Error("422 Duplicate"));
      await expect(createMembership({ user_id: 1, role: "viewer" })).rejects.toThrow("422 Duplicate");
    });
  });
});
