import { describe, it, expect } from "vitest";
import { createDefaultRouter } from "@/router/defaultRoutes";

describe("defaultRouter", () => {
  it("creates a router in hash mode", () => {
    const router = createDefaultRouter();
    expect(router.mode).toBe("hash");
  });

  it("has a root route at /", () => {
    const router = createDefaultRouter();
    const route = router.resolve({ name: "root" });
    expect(route.route.path).toBe("/");
  });
});
