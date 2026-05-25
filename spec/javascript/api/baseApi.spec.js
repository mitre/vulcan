import { describe, it, expect } from "vitest";
import api from "@/api/baseApi";

describe("baseApi", () => {
  it("exports a function with get, post, put, patch, delete methods", () => {
    expect(typeof api.get).toBe("function");
    expect(typeof api.post).toBe("function");
    expect(typeof api.put).toBe("function");
    expect(typeof api.patch).toBe("function");
    expect(typeof api.delete).toBe("function");
  });

  it("has Accept: application/json in default headers", () => {
    expect(api.defaults.headers.common["Accept"]).toBe("application/json");
  });

  it("has X-CSRF-Token set from setup.js meta tag", () => {
    expect(api.defaults.headers.common["X-CSRF-Token"]).toBe("test-csrf-token");
  });
});
