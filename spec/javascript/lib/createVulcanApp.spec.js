import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import Vue from "vue";
import { BModal } from "bootstrap-vue";

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
  //
  // WHY the alias MUST stay on vue/dist/vue.runtime.common.js (v2-avw root
  // cause): the vitest alias only applies to vite-processed code (specs +
  // app/javascript). Externalized node_modules deps (bootstrap-vue, VTU)
  // resolve bare "vue" through Node — always dist/vue.runtime.common.js
  // (the package `main`/`require` export). Pointing the alias at that SAME
  // file gives every consumer ONE shared Vue module instance. Pointing it
  // anywhere else (e.g. the full build vue.common.js) loads a SECOND Vue
  // runtime for spec/app code only: two reactivity systems, two schedulers,
  // two VNode classes. BootstrapVue's BVTransporter portal then fails
  // silently — BVTransporterTarget extends bootstrap-vue's Vue copy while
  // slot vnodes/updates flow through ours, the cross-copy reactive update
  // never patches, and modal content never reaches the document (its $el
  // stays an empty comment node). The single-copy invariant test below
  // turns that silent failure into an explicit one.
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

  // REQUIREMENT: exactly ONE Vue module instance in the test process, and it
  // is the runtime-only build (matching Node's resolution for externalized
  // deps). If either assertion fails, the vitest Vue alias was changed —
  // revert it. Breaking this invariant silently kills BModal/BTooltip/
  // BPopover portal rendering (see divergence comment above).
  describe("test environment Vue build invariants (v2-avw)", () => {
    it("uses the runtime-only Vue build (no template compiler)", () => {
      expect(Vue.compile).toBeUndefined();
    });

    it("shares ONE Vue module instance with bootstrap-vue", () => {
      // BootstrapVue components are Vue.extend constructors created against
      // bootstrap-vue's own `import Vue from "vue"`. Identity with the
      // suite's Vue proves both imports resolved to the same module.
      expect(BModal.super).toBe(Vue);
    });
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
