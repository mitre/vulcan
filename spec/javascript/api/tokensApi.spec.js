import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import {
  listTokens,
  createToken,
  revokeToken,
  adminRevokeToken,
  adminListTokens,
  adminCreateToken,
} from "@/api/tokensApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    delete: vi.fn(),
    patch: vi.fn(),
  },
}));

describe("tokensApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("listTokens calls GET /personal_access_tokens", async () => {
    api.get.mockResolvedValue({ data: [] });
    await listTokens();
    expect(api.get).toHaveBeenCalledWith("/personal_access_tokens");
  });

  it("createToken calls POST /personal_access_tokens with wrapped body", async () => {
    api.post.mockResolvedValue({ data: {} });
    await createToken({ name: "CI token", scopes: ["read"] });
    expect(api.post).toHaveBeenCalledWith("/personal_access_tokens", {
      personal_access_token: { name: "CI token", scopes: ["read"] },
    });
  });

  it("revokeToken calls DELETE /personal_access_tokens/:id", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await revokeToken(7);
    expect(api.delete).toHaveBeenCalledWith("/personal_access_tokens/7");
  });

  it("adminRevokeToken calls DELETE /personal_access_tokens/:id/admin_revoke with audit comment", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await adminRevokeToken(7, "Suspicious activity");
    expect(api.delete).toHaveBeenCalledWith(
      "/personal_access_tokens/7/admin_revoke",
      { data: { audit_comment: "Suspicious activity" } }
    );
  });

  it("adminListTokens calls GET /personal_access_tokens with user_id param", async () => {
    api.get.mockResolvedValue({ data: [] });
    await adminListTokens(42);
    expect(api.get).toHaveBeenCalledWith("/personal_access_tokens", {
      params: { user_id: 42 },
    });
  });

  it("adminCreateToken calls POST /personal_access_tokens with user_id merged", async () => {
    api.post.mockResolvedValue({ data: {} });
    await adminCreateToken(42, { name: "Admin-created", scopes: ["read", "write"] });
    expect(api.post).toHaveBeenCalledWith("/personal_access_tokens", {
      personal_access_token: { name: "Admin-created", scopes: ["read", "write"], user_id: 42 },
    });
  });

  describe("error propagation", () => {
    it("createToken propagates rejected promise", async () => {
      api.post.mockRejectedValue(new Error("422 Validation failed"));
      await expect(createToken({ name: "" })).rejects.toThrow("422 Validation failed");
    });
  });
});
