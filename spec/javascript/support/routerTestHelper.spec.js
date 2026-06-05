import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createTestRouter, mountWithRouter } from "@test/support/routerTestHelper";

describe("routerTestHelper", () => {
  describe("createTestRouter", () => {
    it("creates a hash-mode router with provided routes", () => {
      const router = createTestRouter([
        { path: "/", name: "root" },
        { path: "/rules/:ruleId", name: "rule", props: true },
      ]);

      expect(router.mode).toBe("abstract");
      expect(router.options.routes).toHaveLength(2);
    });

    it("creates a router with default root route when no routes given", () => {
      const router = createTestRouter();

      expect(router.mode).toBe("abstract");
      expect(router.options.routes).toHaveLength(1);
      expect(router.options.routes[0].name).toBe("test-root");
    });

    it("resolves named routes with params", () => {
      const router = createTestRouter([
        { path: "/rules/:ruleId", name: "rule", props: true },
      ]);

      const resolved = router.resolve({ name: "rule", params: { ruleId: "000020" } });
      expect(resolved.route.path).toBe("/rules/000020");
      expect(resolved.route.params.ruleId).toBe("000020");
    });
  });

  describe("mountWithRouter", () => {
    const TestComponent = {
      name: "TestComponent",
      template: "<div>{{ $route.params.ruleId || 'no-rule' }}</div>",
    };

    it("mounts a component with a working router", () => {
      const { wrapper } = mountWithRouter(TestComponent);

      expect(wrapper.vm.$router).toBeDefined();
      expect(wrapper.vm.$route).toBeDefined();
    });

    it("makes $route.params accessible in the component", async () => {
      const routes = [
        { path: "/", name: "root" },
        { path: "/rules/:ruleId", name: "rule", props: true },
      ];
      const { wrapper, router } = mountWithRouter(TestComponent, { routes });

      router.push({ name: "rule", params: { ruleId: "000020" } });
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.$route.params.ruleId).toBe("000020");
      expect(wrapper.text()).toBe("000020");
    });

    it("accepts mount options alongside router", () => {
      const PropsComponent = {
        name: "PropsComp",
        props: { label: String },
        template: "<div>{{ label }}</div>",
      };
      const { wrapper } = mountWithRouter(PropsComponent, {
        propsData: { label: "Hello" },
      });

      expect(wrapper.text()).toBe("Hello");
    });

    it("returns router for programmatic navigation in tests", async () => {
      const routes = [
        { path: "/", name: "root" },
        { path: "/items/:id", name: "item" },
      ];
      const { wrapper, router } = mountWithRouter(TestComponent, { routes });

      router.push({ name: "item", params: { id: "42" } });
      await wrapper.vm.$nextTick();

      expect(wrapper.vm.$route.name).toBe("item");
      expect(wrapper.vm.$route.params.id).toBe("42");
    });
  });
});
