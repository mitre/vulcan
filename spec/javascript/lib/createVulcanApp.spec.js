import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import Vue from "vue";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

import { createVulcanApp } from "@/lib/createVulcanApp";

describe("createVulcanApp", () => {
  let el;

  beforeEach(() => {
    el = document.createElement("div");
    el.id = "test-app";
    document.body.appendChild(el);
  });

  afterEach(() => {
    el.remove();
  });

  it("creates a Vue instance mounted on the given element", () => {
    const DummyComponent = { name: "Dummy", template: "<div>hello</div>" };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Dummy",
      component: DummyComponent,
    });
    expect(vm).toBeInstanceOf(Vue);
    vm.$destroy();
  });

  it("registers the component globally by name", () => {
    const DummyComponent = { name: "TestComp", template: "<div>hi</div>" };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Testcomp",
      component: DummyComponent,
    });
    expect(vm.$options.components.Testcomp).toBeDefined();
    vm.$destroy();
  });

  it("installs Pinia on the instance", () => {
    const DummyComponent = { name: "PiniaTest", template: "<div>p</div>" };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Piniatest",
      component: DummyComponent,
    });
    expect(vm.$pinia).toBeDefined();
    vm.$destroy();
  });
});
