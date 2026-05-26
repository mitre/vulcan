import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import { globalSearch, getRelatedRules } from "@/api/searchApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("searchApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("globalSearch calls GET /api/search/global with params", async () => {
    api.get.mockResolvedValue({ data: { results: [] } });
    await globalSearch({ q: "test", limit: 10 });
    expect(api.get).toHaveBeenCalledWith("/api/search/global", { params: { q: "test", limit: 10 } });
  });

  it("getRelatedRules calls GET /rules/:id/search/related_rules", async () => {
    api.get.mockResolvedValue({ data: [] });
    await getRelatedRules(5);
    expect(api.get).toHaveBeenCalledWith("/rules/5/search/related_rules");
  });
});
