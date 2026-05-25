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

  it("createMembership posts to /memberships.json", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createMembership(1, 2, "viewer");
    expect(api.post).toHaveBeenCalledWith("/memberships.json", {
      membership: { project_id: 1, user_id: 2, role: "viewer" },
    });
  });

  it("updateMembership puts to /memberships/:id.json", async () => {
    api.put.mockResolvedValue({ data: {} });
    await updateMembership(5, "admin");
    expect(api.put).toHaveBeenCalledWith("/memberships/5.json", {
      membership: { role: "admin" },
    });
  });

  it("deleteMembership deletes /memberships/:id.json", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteMembership(5);
    expect(api.delete).toHaveBeenCalledWith("/memberships/5.json");
  });

  it("deleteAccessRequest deletes /project_access_requests/:id.json", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await deleteAccessRequest(3);
    expect(api.delete).toHaveBeenCalledWith("/project_access_requests/3.json");
  });
});
