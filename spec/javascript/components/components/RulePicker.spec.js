import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RulePicker from "@/components/components/RulePicker.vue";
import axios from "axios";

vi.mock("axios");

const flushPromises = async (wrapper) => {
  await new Promise((resolve) => setTimeout(resolve, 0));
  if (wrapper) await wrapper.vm.$nextTick();
};

const rulesPayload = {
  rules: [
    {
      id: 1,
      rule_id: "CNTR-01-000010",
      displayed_name: "CNTR-01-000010",
      title: "Parent control for container runtime",
      satisfied_by: [],
      satisfies: [{ id: 2, rule_id: "CNTR-01-001002" }, { id: 3, rule_id: "CNTR-01-001003" }],
    },
    {
      id: 2,
      rule_id: "CNTR-01-001002",
      displayed_name: "CNTR-01-001002",
      title: "Child control A",
      satisfied_by: [{ id: 1, rule_id: "CNTR-01-000010" }],
      satisfies: [],
    },
    {
      id: 3,
      rule_id: "CNTR-01-001003",
      displayed_name: "CNTR-01-001003",
      title: "Child control B",
      satisfied_by: [{ id: 1, rule_id: "CNTR-01-000010" }],
      satisfies: [],
    },
    {
      id: 4,
      rule_id: "CNTR-01-000020",
      displayed_name: "CNTR-01-000020",
      title: "Unrelated sibling control",
      satisfied_by: [],
      satisfies: [],
    },
  ],
};

function baseProps(overrides = {}) {
  return {
    componentId: 5,
    excludeRuleId: 2,
    selectedRuleId: null,
    ...overrides,
  };
}

describe("RulePicker", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    axios.get.mockResolvedValue({ data: rulesPayload });
  });

  it("fetches rules on mount and excludes the source rule", async () => {
    const w = mount(RulePicker, { localVue, propsData: baseProps() });
    await flushPromises(w);
    const items = w.findAll("[role='option']");
    expect(items.length).toBe(3);
    const ids = items.wrappers.map((item) => item.text());
    expect(ids.some((t) => t.includes("CNTR-01-001002"))).toBe(false);
  });

  it("shows 'Parent' badge and highlight on rules that satisfy the source rule", async () => {
    const w = mount(RulePicker, {
      localVue,
      propsData: baseProps({ excludeRuleId: 2 }),
    });
    await flushPromises(w);
    const parentItem = w.find("[data-test='target-rule-1']");
    const badge = parentItem.find("[data-test='relationship-badge']");
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("Parent");
    expect(parentItem.classes()).toContain("rule-candidate--parent");
  });

  it("shows 'Child' badge and highlight on rules that the source rule satisfies", async () => {
    const w = mount(RulePicker, {
      localVue,
      propsData: baseProps({ excludeRuleId: 1 }),
    });
    await flushPromises(w);
    const childItem = w.find("[data-test='target-rule-2']");
    const badge = childItem.find("[data-test='relationship-badge']");
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("Child");
    expect(childItem.classes()).toContain("rule-candidate--child");
  });

  it("shows no badge or highlight on unrelated rules", async () => {
    const w = mount(RulePicker, {
      localVue,
      propsData: baseProps({ excludeRuleId: 2 }),
    });
    await flushPromises(w);
    const siblingItem = w.find("[data-test='target-rule-4']");
    expect(siblingItem.find("[data-test='relationship-badge']").exists()).toBe(false);
    expect(siblingItem.classes()).not.toContain("rule-candidate--parent");
    expect(siblingItem.classes()).not.toContain("rule-candidate--child");
  });

  it("emits selected with rule ID on click", async () => {
    const w = mount(RulePicker, { localVue, propsData: baseProps() });
    await flushPromises(w);
    await w.find("[data-test='target-rule-1']").trigger("click");
    expect(w.emitted("selected")[0][0]).toBe(1);
  });

  it("highlights the selected rule", async () => {
    const w = mount(RulePicker, {
      localVue,
      propsData: baseProps({ selectedRuleId: 1 }),
    });
    await flushPromises(w);
    const selected = w.find("[data-test='target-rule-1']");
    expect(selected.classes()).toContain("border-primary");
  });

  it("filters rules by search query", async () => {
    const w = mount(RulePicker, { localVue, propsData: baseProps() });
    await flushPromises(w);
    w.vm.query = "000020";
    await w.vm.$nextTick();
    const items = w.findAll("[role='option']");
    expect(items.length).toBe(1);
    expect(items.at(0).text()).toContain("CNTR-01-000020");
  });

  it("sorts parent rules first in the list", async () => {
    const w = mount(RulePicker, {
      localVue,
      propsData: baseProps({ excludeRuleId: 2 }),
    });
    await flushPromises(w);
    const items = w.findAll("[role='option']");
    expect(items.at(0).text()).toContain("CNTR-01-000010");
    expect(items.at(0).find("[data-test='relationship-badge']").text()).toBe("Parent");
  });
});
