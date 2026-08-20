import { describe, it, expect, vi, beforeEach } from "vitest";
import api from "@/api/baseApi";
import { acknowledgeConsent } from "@/api/authApi";

vi.mock("@/api/baseApi", () => ({
  default: { get: vi.fn(), post: vi.fn(), put: vi.fn(), patch: vi.fn(), delete: vi.fn() },
}));

// signOut was removed: sign-out is a navigational rails-ujs DELETE link in
// the navbar (Devise HTML flow sets the signed-out flash), not an ajax call.

describe("authApi", () => {
  beforeEach(() => vi.resetAllMocks());

  it("acknowledgeConsent calls POST /consent/acknowledge", async () => {
    api.post.mockResolvedValue({ data: {} });
    await acknowledgeConsent();
    expect(api.post).toHaveBeenCalledWith("/consent/acknowledge");
  });
});
