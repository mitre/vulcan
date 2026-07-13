import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import SatisfiedByIndicator from "@/components/shared/SatisfiedByIndicator.vue";

function createWrapper(propsData = {}, options = {}) {
  return mount(SatisfiedByIndicator, { localVue, propsData, ...options });
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
    const wrapper = createWrapper({ parentRules: [], componentPrefix: "CNTR-00" });
    expect(wrapper.html()).toBe("");
  });

  it("renders the indicator when parentRules is provided", () => {
    const wrapper = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    expect(wrapper.find(".satisfied-by-indicator").exists()).toBe(true);
  });

  it("displays the parent rule displayed name", () => {
    const wrapper = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    expect(wrapper.text()).toContain("CNTR-00-000020");
  });

  it("emits navigate with the parent rule id when Go to parent is clicked", async () => {
    const wrapper = createWrapper({ parentRules, componentPrefix: "CNTR-00" });
    const btn = wrapper.find("[data-testid='go-to-parent']");
    await btn.trigger("click");
    expect(wrapper.emitted("navigate")).toBeTruthy();
    expect(wrapper.emitted("navigate")[0]).toEqual([100]);
  });

  it("renders default slot content", () => {
    const wrapper = createWrapper(
      { parentRules, componentPrefix: "CNTR-00" },
      { slots: { default: "<span class='custom-slot'>Extra context</span>" } },
    );
    expect(wrapper.find(".custom-slot").exists()).toBe(true);
    expect(wrapper.text()).toContain("Extra context");
  });

  it("renders actions slot content", () => {
    const wrapper = createWrapper(
      { parentRules, componentPrefix: "CNTR-00" },
      { slots: { actions: "<button class='custom-action'>Custom</button>" } },
    );
    expect(wrapper.find(".custom-action").exists()).toBe(true);
  });

  it("shows multiple parents when more than one satisfied_by exists", () => {
    const multiParent = [
      { id: 100, rule_id: "000020", srg_id: "SRG-OS-000002", component_prefix: "CNTR-00" },
      { id: 200, rule_id: "000030", srg_id: "SRG-OS-000003", component_prefix: "CNTR-00" },
    ];
    const wrapper = createWrapper({ parentRules: multiParent, componentPrefix: "CNTR-00" });
    expect(wrapper.text()).toContain("CNTR-00-000020");
    expect(wrapper.text()).toContain("CNTR-00-000030");
  });

  it("emits navigate once per distinct parent button in multi-parent mode", async () => {
    const multiParent = [
      { id: 100, rule_id: "000020", srg_id: "SRG-OS-000002", component_prefix: "CNTR-00" },
      { id: 200, rule_id: "000030", srg_id: "SRG-OS-000003", component_prefix: "CNTR-00" },
    ];
    const wrapper = createWrapper({ parentRules: multiParent, componentPrefix: "CNTR-00" });
    const buttons = wrapper.findAll("[data-testid='go-to-parent']");
    expect(buttons.length).toBe(2);
    await buttons.at(1).trigger("click");
    expect(wrapper.emitted("navigate")[0]).toEqual([200]);
  });

  // The 3 container-width modes (narrow badge / medium compact / wide banner)
  // cannot be asserted in jsdom — it has no layout engine, so @container
  // conditions never evaluate. That behavior is verified in a real browser
  // via computed-style checks at wide/medium/narrow container widths.
});
