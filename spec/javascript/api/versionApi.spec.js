import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import { getVersion } from "@/api/versionApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("versionApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("getVersion calls GET /api/version", async () => {
    api.get.mockResolvedValue({ data: { version: "2.3.7" } });
    const result = await getVersion();
    expect(api.get).toHaveBeenCalledWith("/api/version");
    expect(result.data.version).toBe("2.3.7");
  });
});
