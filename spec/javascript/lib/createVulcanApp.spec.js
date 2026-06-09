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
  let warnings;

  // KNOWN ENV DIVERGENCE: createVulcanApp mounts via `new Vue({ el })` and
  // compiles the element's markup (the HAML→Vue pack pattern). Production
  // uses the full Vue build (esbuild useFullVue: true); this suite aliases
  // the runtime-only build for VTU. Vue's official warnHandler captures the
  // resulting "runtime-only build" warning so it is ASSERTED, not leaked —
  // and any OTHER warning fails the test.
  beforeEach(() => {
    el = document.createElement("div");
    el.id = "test-app";
    document.body.appendChild(el);
    warnings = [];
    Vue.config.warnHandler = (msg) => warnings.push(msg);
  });

  afterEach(() => {
    el.remove();
    Vue.config.warnHandler = undefined;
    const unexpected = warnings.filter((m) => !m.includes("runtime-only build"));
    expect(unexpected).toEqual([]);
  });

  // Dummy components use render functions — the forward-compatible form
  // (identical in Vue 2 and Vue 3, no template compiler dependency).
  it("creates a Vue instance mounted on the given element", () => {
    const DummyComponent = { name: "Dummy", render: (h) => h("div", "hello") };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Dummy",
      component: DummyComponent,
    });
    expect(vm).toBeInstanceOf(Vue);
    vm.$destroy();
  });

  it("registers the component globally by name", () => {
    const DummyComponent = { name: "TestComp", render: (h) => h("div", "hi") };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Testcomp",
      component: DummyComponent,
    });
    expect(vm.$options.components.Testcomp).toBeDefined();
    vm.$destroy();
  });

  it("installs Pinia on the instance", () => {
    const DummyComponent = { name: "PiniaTest", render: (h) => h("div", "p") };
    const vm = createVulcanApp({
      el: "#test-app",
      componentName: "Piniatest",
      component: DummyComponent,
    });
    expect(vm.$pinia).toBeDefined();
    vm.$destroy();
  });

});
