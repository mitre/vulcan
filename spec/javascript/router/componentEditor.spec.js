import { describe, it, expect, beforeEach } from "vitest";
import { createComponentEditorRouter } from "@/router/componentEditor";

describe("componentEditorRouter", () => {
  let router;

  beforeEach(() => {
    router = createComponentEditorRouter();
  });

  it("creates a router in hash mode", () => {
    expect(router.mode).toBe("hash");
  });

  it("has an editor-root route at /", () => {
    const route = router.resolve({ name: "editor-root" });
    expect(route.route.path).toBe("/");
  });

  it("has a rule route at /rules/:ruleId", () => {
    const route = router.resolve({ name: "rule", params: { ruleId: "000020" } });
    expect(route.route.path).toBe("/rules/000020");
  });

  it("resolves /rules/000020 to the rule route with correct params", async () => {
    router.push("/rules/000020");
    await router.onReady(() => {});

    expect(router.currentRoute.name).toBe("rule");
    expect(router.currentRoute.params.ruleId).toBe("000020");
  });

  it("includes breadcrumb meta on routes", () => {
    const root = router.resolve({ name: "editor-root" });
    expect(root.route.meta.breadcrumb).toBe("Editor");

    const rule = router.resolve({ name: "rule", params: { ruleId: "1" } });
    expect(rule.route.meta.breadcrumb).toBe("Rule");
  });

  it("passes ruleId as prop when props: true", () => {
    const match = router.resolve({ name: "rule", params: { ruleId: "000020" } });
    const routeConfig = router.options.routes.find((r) => r.name === "rule");
    expect(routeConfig.props).toBe(true);
  });
});
