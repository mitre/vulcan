import { describe, it, expect, vi } from "vitest";
import api, { handleSessionExpired } from "@/api/baseApi";

describe("baseApi", () => {
  it("exports an object with get, post, put, patch, delete methods", () => {
    expect(typeof api.get).toBe("function");
    expect(typeof api.post).toBe("function");
    expect(typeof api.put).toBe("function");
    expect(typeof api.patch).toBe("function");
    expect(typeof api.delete).toBe("function");
  });

  it("does not expose axios-specific properties", () => {
    expect(api.create).toBeUndefined();
    expect(api.interceptors).toBeUndefined();
  });

  it("exposes setHeader for controlled header access", () => {
    expect(typeof api.setHeader).toBe("function");
  });

  it("exposes defaults.headers for legacy FormMixin compatibility", () => {
    expect(api.defaults).toBeDefined();
    expect(api.defaults.headers).toBeDefined();
    expect(api.defaults.headers.common).toBeDefined();
  });

  it("uses ky as the underlying HTTP client", () => {
    expect(api._client).toBe("ky");
  });

  // ── expired-session 401 handling ───────────────────────────────────
  // REQUIREMENT: a 401 on ajax means the session died (timeout, or the
  // user signed in elsewhere via session_limitable). The page must
  // RELOAD — a navigational request lets Devise's FailureApp set the
  // cause-specific flash and store user_return_to — rather than jumping
  // straight to the sign-in path (which loses both).
  describe("handleSessionExpired", () => {
    const fakeLoc = (pathname = "/projects/1") => ({ pathname, reload: vi.fn() });

    it("reloads the page on 401 so Devise sets flash + return-to", () => {
      const loc = fakeLoc();
      handleSessionExpired({ response: { status: 401 } }, loc);
      expect(loc.reload).toHaveBeenCalledTimes(1);
    });

    it("does nothing on non-401 responses", () => {
      const loc = fakeLoc();
      handleSessionExpired({ response: { status: 200 } }, loc);
      handleSessionExpired({ response: { status: 403 } }, loc);
      expect(loc.reload).not.toHaveBeenCalled();
    });

    it("does nothing when already on the sign-in page (no reload loop)", () => {
      const loc = fakeLoc("/users/sign_in");
      handleSessionExpired({ response: { status: 401 } }, loc);
      expect(loc.reload).not.toHaveBeenCalled();
    });
  });
});
