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

import { createVulcanApp, sharedPinia } from "@/lib/createVulcanApp";
import { setActivePinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";

vi.mock("@/api/componentsApi", () => ({ getComments: vi.fn() }));
vi.mock("@/api/reviewsApi", () => ({
  getReviewResponses: vi.fn(),
  createRuleReview: vi.fn(),
  createComponentReview: vi.fn(),
  triageReview: vi.fn(),
  bulkTriageReviews: vi.fn(),
}));

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

  it("resets store state on turbolinks:before-visit", () => {
    setActivePinia(sharedPinia);
    const store = useCommentsStore();
    store.cache["38:{}"] = { rows: [{ id: 1 }] };
    expect(Object.keys(store.cache)).toHaveLength(1);

    document.dispatchEvent(new Event("turbolinks:before-visit"));

    expect(Object.keys(store.cache)).toHaveLength(0);
    expect(store.loading).toBe(false);
    expect(store.error).toBeNull();
  });
});
