import { describe, it, expect, vi, beforeEach } from "vitest";

describe("baseApi", () => {
  beforeEach(() => {
    vi.resetModules();
    document.head.innerHTML = "";
  });

  it("creates an axios instance with X-CSRF-Token from meta tag", async () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "test-csrf-token-abc123";
    document.head.appendChild(meta);

    const { default: api } = await import("@/api/baseApi");
    expect(api.defaults.headers.common["X-CSRF-Token"]).toBe("test-csrf-token-abc123");
  });

  it("sets Accept header to application/json", async () => {
    const { default: api } = await import("@/api/baseApi");
    expect(api.defaults.headers.common["Accept"]).toBe("application/json");
  });

  it("does not crash when no csrf-token meta tag exists", async () => {
    const { default: api } = await import("@/api/baseApi");
    expect(api.defaults.headers.common["X-CSRF-Token"]).toBeUndefined();
  });
});
