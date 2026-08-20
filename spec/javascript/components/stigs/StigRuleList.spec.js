/**
 * StigRuleList Regression Tests
 *
 * REQUIREMENTS:
 *
 * 1. The rule-field filter (SRG ID vs STIG ID) renders as FilterDropdown,
 *    not <b-form-select>. Reason: <b-form-select> wraps a native browser
 *    <select> whose menu is browser-positioned and clips at viewport
 *    edges. FilterDropdown uses <b-dropdown boundary="viewport"> which
 *    stays inside the visible window.
 * 2. Field selection still drives the displayed column (SRG ID vs version).
 *    The migration MUST NOT change behavior — only the rendering primitive.
 */
import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import StigRuleList from "@/components/stigs/StigRuleList.vue";

describe("StigRuleList — Task 28 FilterDropdown migration", () => {
  const sampleRules = [
    { id: 1, srg_id: "SRG-OS-000001", version: "RHEL-08-010100", rule_severity: "high" },
    { id: 2, srg_id: "SRG-OS-000002", version: "RHEL-08-010200", rule_severity: "medium" },
  ];

  const mountIt = (overrides = {}) =>
    mount(StigRuleList, {
      localVue,
      propsData: {
        rules: sampleRules,
        initialSelectedRule: sampleRules[0],
        ...overrides,
      },
    });

  it("renders FilterDropdown for the rule-field filter (not native <select>)", () => {
    const w = mountIt();
    expect(w.findComponent({ name: "FilterDropdown" }).exists()).toBe(true);
    expect(w.find("select").exists()).toBe(false);
  });

  it("FilterDropdown is bound to `field` and exposes both rule-field options", () => {
    const w = mountIt();
    const fd = w.findComponent({ name: "FilterDropdown" });
    expect(fd.props("value")).toBe("SRG ID");
    const optionValues = fd.props("options").map((o) => o.value);
    expect(optionValues).toEqual(["SRG ID", "STIG ID"]);
  });

  it("emitting 'input' from FilterDropdown updates the field selection", async () => {
    const w = mountIt();
    const fd = w.findComponent({ name: "FilterDropdown" });
    fd.vm.$emit("input", "STIG ID");
    await w.vm.$nextTick();
    expect(w.vm.field).toBe("STIG ID");
  });

  // This is a STIG-only catalog surface: its nouns read ruleTerm("stig")
  // explicitly, and these literal pins hold the corrected user-visible
  // wording (a kind-WRONG "Requirements" here was a shipped bug).
  it("pins the stig-kind list heading and search placeholder", () => {
    const w = mountIt();
    const headings = w.findAll("h5.card-title").wrappers.map((h) => h.text());
    expect(headings).toContain("Rules");
    expect(w.text()).not.toMatch(/\bRequirements\b/);
    const search = w.find('input[placeholder^="Search"]');
    expect(search.attributes("placeholder")).toBe("Search Rule by STIG ID or SRG ID");
  });
});
