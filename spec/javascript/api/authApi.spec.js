import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import { signOut, acknowledgeConsent } from "@/api/authApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

describe("authApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("signOut calls DELETE with the provided sign-out path", async () => {
    api.delete.mockResolvedValue({ data: {} });
    await signOut("/users/sign_out");
    expect(api.delete).toHaveBeenCalledWith("/users/sign_out");
  });

  it("acknowledgeConsent calls POST /consent/acknowledge", async () => {
    api.post.mockResolvedValue({ data: {} });
    await acknowledgeConsent();
    expect(api.post).toHaveBeenCalledWith("/consent/acknowledge");
  });

  describe("error propagation", () => {
    it("signOut propagates rejected promise", async () => {
      api.delete.mockRejectedValue(new Error("401 Unauthorized"));
      await expect(signOut("/users/sign_out")).rejects.toThrow("401 Unauthorized");
    });
  });
});
