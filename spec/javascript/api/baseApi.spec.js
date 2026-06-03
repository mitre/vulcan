import { describe, it, expect } from "vitest";
import api from "@/api/baseApi";

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
});
