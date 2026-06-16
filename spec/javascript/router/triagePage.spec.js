import { describe, it, expect, beforeEach } from "vitest";
import { createTriageRouter } from "@/router/triagePage";

describe("triageRouter", () => {
  let router;

  beforeEach(() => {
    router = createTriageRouter();
  });

  it("creates a router in hash mode", () => {
    expect(router.mode).toBe("hash");
  });

  it("has a triage-root route at /", () => {
    const route = router.resolve({ name: "triage-root" });
    expect(route.route.path).toBe("/");
  });

  it("has a comment route at /comments/:commentId", () => {
    const route = router.resolve({
      name: "comment",
      params: { commentId: "42" },
    });
    expect(route.route.path).toBe("/comments/42");
  });

  it("resolves /comments/42 to the comment route with correct params", async () => {
    router.push("/comments/42");
    await router.onReady(() => {});

    expect(router.currentRoute.name).toBe("comment");
    expect(router.currentRoute.params.commentId).toBe("42");
  });
});
