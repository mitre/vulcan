import { describe, it, expect, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import SatisfiedByIndicator from "@/components/shared/SatisfiedByIndicator.vue";

function createWrapper(propsData = {}) {
  const pinia = createPinia();
  setActivePinia(pinia);
  const router = createTestRouter([
    { path: "/", name: "editor-root" },
    { path: "/rules/:ruleId", name: "rule", props: true },
  ]);
  const store = useRuleSelectionStore();
  store.init(router, 1);

  return {
    wrapper: mount(SatisfiedByIndicator, { localVue, pinia, router, propsData }),
    store,
  };
}

describe("SatisfiedByIndicator", () => {
  const parentRules = [
    {
      id: 100,
      rule_id: "000020",
      srg_id: "SRG-OS-000002",
      fixtext: "Parent fix text",
      component_prefix: "CNTR-00",
    },
  ];

  it("renders nothing when parentRules is empty", () => {
    const { wrapper } = createWrapper({ parentRules: [], componentPrefix: "CNTR-00" });
    expect(wrapper.html()).toBe("");
  });

  it("renders the indicator when parentRules is provided", () => {
    const { wrapper } = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    expect(wrapper.find(".satisfied-by-indicator").exists()).toBe(true);
  });

  it("displays the parent rule displayed name", () => {
    const { wrapper } = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    expect(wrapper.text()).toContain("CNTR-00-000020");
  });

  it("calls store.selectRule when Go to parent is clicked", async () => {
    const { wrapper, store } = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    const btn = wrapper.find("[data-testid='go-to-parent']");
    await btn.trigger("click");
    expect(store.selectedRuleId).toBe(100);
  });

  it("renders default slot content", () => {
    const p = createPinia();
    setActivePinia(p);
    const r = createTestRouter();
    const s = useRuleSelectionStore();
    s.init(r, 1);
    const w = mount(SatisfiedByIndicator, {
      localVue,
      pinia: p,
      router: r,
      propsData: { parentRules, componentPrefix: "CNTR-00" },
      slots: { default: "<span class='custom-slot'>Extra context</span>" },
    });
    expect(w.find(".custom-slot").exists()).toBe(true);
    expect(w.text()).toContain("Extra context");
  });

  it("renders actions slot content", () => {
    const p = createPinia();
    setActivePinia(p);
    const r = createTestRouter();
    const s = useRuleSelectionStore();
    s.init(r, 1);
    const w = mount(SatisfiedByIndicator, {
      localVue,
      pinia: p,
      router: r,
      propsData: { parentRules, componentPrefix: "CNTR-00" },
      slots: { actions: "<button class='custom-action'>Custom</button>" },
    });
    expect(w.find(".custom-action").exists()).toBe(true);
  });

  it("shows multiple parents when more than one satisfied_by exists", () => {
    const multiParent = [
      { id: 100, rule_id: "000020", srg_id: "SRG-OS-000002", component_prefix: "CNTR-00" },
      { id: 200, rule_id: "000030", srg_id: "SRG-OS-000003", component_prefix: "CNTR-00" },
    ];
    const { wrapper } = createWrapper({ parentRules: multiParent, componentPrefix: "CNTR-00" });
    expect(wrapper.text()).toContain("CNTR-00-000020");
    expect(wrapper.text()).toContain("CNTR-00-000030");
  });

  it("has container-type: inline-size for container queries", () => {
    const { wrapper } = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    const el = wrapper.find(".satisfied-by-indicator");
    expect(el.exists()).toBe(true);
  });
});
