import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleList from "@/components/benchmarks/RuleList.vue";
import { RULE_TERM } from "@/constants/terminology";

/**
 * RuleList Component Requirements
 *
 * REQUIREMENTS:
 *
 * 1. DROPDOWN OPTIONS (no "Title"):
 *    - STIG: [Rule ID, STIG ID, SRG ID]
 *    - SRG:  [SRG ID, Rule ID]
 *    - Default selected: first option in list
 *
 * 2. DISPLAY FIELD:
 *    - "Rule ID" option → shows truncated rule_id (SV-203591)
 *    - "STIG ID" option → shows version column
 *    - "SRG ID" option → shows version (SRG) or srg_id (STIG)
 *
 * 3. SORT:
 *    - Sorts by the data field underlying the selected option
 *
 * 4. SEARCH PLACEHOLDER:
 *    - STIG: "Search by STIG ID, Rule ID, or title"
 *    - SRG:  "Search by SRG ID, Rule ID, or title"
 *
 * 5. SEARCH FUNCTIONALITY:
 *    - Searches across rule_id, version, and title
 */
describe("RuleList", () => {
  let wrapper;

  const stigRules = [
    {
      id: 1,
      rule_id: "SV-203591r557031_rule",
      version: "RHEL-08-010190",
      srg_id: "SRG-OS-000480",
      title: "First STIG Rule",
      rule_severity: "high",
    },
    {
      id: 2,
      rule_id: "SV-203592r557032_rule",
      version: "RHEL-08-010200",
      srg_id: "SRG-OS-000001",
      title: "Second STIG Rule",
      rule_severity: "medium",
    },
    {
      id: 3,
      rule_id: "SV-203593r557033_rule",
      version: "RHEL-08-010210",
      srg_id: "SRG-OS-000120",
      title: "Third STIG Rule",
      rule_severity: "low",
    },
  ];

  const srgRules = [
    {
      id: 1,
      rule_id: "SV-203591r557031_rule",
      version: "SRG-OS-000001-GPOS-00001",
      title: "First SRG Rule",
      rule_severity: "high",
    },
    {
      id: 2,
      rule_id: "SV-203592r557032_rule",
      version: "SRG-OS-000002-GPOS-00002",
      title: "Second SRG Rule",
      rule_severity: "medium",
    },
    {
      id: 3,
      rule_id: "SV-203593r557033_rule",
      version: "SRG-OS-000120-GPOS-00120",
      title: "Third SRG Rule",
      rule_severity: "low",
    },
  ];

  const createWrapper = (props = {}) => {
    return shallowMount(RuleList, {
      localVue,
      propsData: {
        rules: stigRules,
        initialSelectedRule: stigRules[0],
        type: "stig",
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  // ==========================================
  // TERMINOLOGY INTEGRATION
  // ==========================================
  describe("RULE_TERM integration", () => {
    it("uses RULE_TERM.plural for list title", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain(RULE_TERM.plural);
    });
  });

  // ==========================================
  // TYPE PROP
  // ==========================================
  describe("type prop", () => {
    it("accepts stig type", () => {
      wrapper = createWrapper({ type: "stig" });
      expect(wrapper.props("type")).toBe("stig");
    });

    it("accepts srg type", () => {
      wrapper = createWrapper({ type: "srg" });
      expect(wrapper.props("type")).toBe("srg");
    });

    it("type prop is required", () => {
      expect(RuleList.props.type.required).toBe(true);
    });
  });

  // ==========================================
  // DROPDOWN OPTIONS
  // ==========================================
  describe("dropdown options", () => {
    it("STIG mode has Rule ID, STIG ID, SRG ID options", () => {
      wrapper = createWrapper({ type: "stig" });
      const options = wrapper.vm.fieldOptions;
      expect(options).toHaveLength(3);
      expect(options[0]).toEqual({ value: "rule_id", text: "Rule ID" });
      expect(options[1]).toEqual({ value: "stig_id", text: "STIG ID" });
      expect(options[2]).toEqual({ value: "srg_id", text: "SRG ID" });
    });

    it("SRG mode has SRG ID, Rule ID options", () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      const options = wrapper.vm.fieldOptions;
      expect(options).toHaveLength(2);
      expect(options[0]).toEqual({ value: "srg_id", text: "SRG ID" });
      expect(options[1]).toEqual({ value: "rule_id", text: "Rule ID" });
    });

    it('does not have a "Title" option in STIG mode', () => {
      wrapper = createWrapper({ type: "stig" });
      const options = wrapper.vm.fieldOptions;
      const titleOption = options.find((o) => o.text === "Title");
      expect(titleOption).toBeUndefined();
    });

    it('does not have a "Title" option in SRG mode', () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      const options = wrapper.vm.fieldOptions;
      const titleOption = options.find((o) => o.text === "Title");
      expect(titleOption).toBeUndefined();
    });

    it("default field for STIG is rule_id", () => {
      wrapper = createWrapper({ type: "stig" });
      expect(wrapper.vm.field).toBe("rule_id");
    });

    it("default field for SRG is srg_id", () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      expect(wrapper.vm.field).toBe("srg_id");
    });
  });

  // ==========================================
  // DISPLAY FIELD
  // ==========================================
  describe("displayField", () => {
    it("Rule ID option shows truncated rule_id", () => {
      wrapper = createWrapper({ type: "stig" });
      wrapper.setData({ field: "rule_id" });
      const display = wrapper.vm.displayField(stigRules[0]);
      expect(display).toBe("SV-203591");
      // Should NOT contain the release suffix
      expect(display).not.toContain("r557031");
    });

    it("STIG ID option shows version column", () => {
      wrapper = createWrapper({ type: "stig" });
      wrapper.setData({ field: "stig_id" });
      const display = wrapper.vm.displayField(stigRules[0]);
      expect(display).toBe("RHEL-08-010190");
    });

    it("SRG ID option on STIG shows srg_id column", () => {
      wrapper = createWrapper({ type: "stig" });
      wrapper.setData({ field: "srg_id" });
      const display = wrapper.vm.displayField(stigRules[0]);
      expect(display).toBe("SRG-OS-000480");
    });

    it("SRG ID option on SRG shows version column", () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      wrapper.setData({ field: "srg_id" });
      const display = wrapper.vm.displayField(srgRules[0]);
      expect(display).toBe("SRG-OS-000001-GPOS-00001");
    });

    it("Rule ID option on SRG shows truncated rule_id", () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      wrapper.setData({ field: "rule_id" });
      const display = wrapper.vm.displayField(srgRules[0]);
      expect(display).toBe("SV-203591");
    });
  });

  // ==========================================
  // SORT
  // ==========================================
  describe("sorting", () => {
    it("sorts by rule_id ascending", async () => {
      wrapper = createWrapper({ type: "stig" });
      await wrapper.setData({ field: "rule_id", sortOrder: "asc" });
      const sorted = wrapper.vm.sortedRules;
      expect(sorted[0].rule_id).toBe("SV-203591r557031_rule");
      expect(sorted[2].rule_id).toBe("SV-203593r557033_rule");
    });

    it("sorts by STIG ID (version) ascending", async () => {
      wrapper = createWrapper({ type: "stig" });
      await wrapper.setData({ field: "stig_id", sortOrder: "asc" });
      const sorted = wrapper.vm.sortedRules;
      expect(sorted[0].version).toBe("RHEL-08-010190");
      expect(sorted[2].version).toBe("RHEL-08-010210");
    });

    it("sorts by SRG ID ascending on STIG view", async () => {
      wrapper = createWrapper({ type: "stig" });
      await wrapper.setData({ field: "srg_id", sortOrder: "asc" });
      const sorted = wrapper.vm.sortedRules;
      expect(sorted[0].srg_id).toBe("SRG-OS-000001");
      expect(sorted[2].srg_id).toBe("SRG-OS-000480");
    });

    it("sorts descending when sortOrder is desc", async () => {
      wrapper = createWrapper({ type: "stig" });
      await wrapper.setData({ field: "stig_id", sortOrder: "desc" });
      const sorted = wrapper.vm.sortedRules;
      expect(sorted[0].version).toBe("RHEL-08-010210");
      expect(sorted[2].version).toBe("RHEL-08-010190");
    });
  });

  // ==========================================
  // SEARCH PLACEHOLDER
  // ==========================================
  describe("search placeholder", () => {
    it("STIG placeholder mentions STIG ID, Rule ID, and title", () => {
      wrapper = createWrapper({ type: "stig" });
      const placeholder = wrapper.find('input[type="text"]').attributes("placeholder");
      expect(placeholder).toBe("Search by STIG ID, Rule ID, or title");
    });

    it("SRG placeholder mentions SRG ID, Rule ID, and title", () => {
      wrapper = createWrapper({ type: "srg", rules: srgRules, initialSelectedRule: srgRules[0] });
      const placeholder = wrapper.find('input[type="text"]').attributes("placeholder");
      expect(placeholder).toBe("Search by SRG ID, Rule ID, or title");
    });
  });

  // ==========================================
  // SEARCH FUNCTIONALITY
  // ==========================================
  describe("search functionality", () => {
    it("filters by rule_id", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ searchText: "SV-203591" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(1);
      expect(filtered[0].id).toBe(1);
    });

    it("filters by version (STIG ID)", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ searchText: "RHEL-08-010200" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(1);
      expect(filtered[0].id).toBe(2);
    });

    it("filters by title", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ searchText: "Third" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(1);
      expect(filtered[0].id).toBe(3);
    });

    it("search is case-insensitive", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ searchText: "rhel-08-010190" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(1);
    });
  });

  // ==========================================
  // SEVERITY COUNT REACTIVITY
  // ==========================================
  describe("severity counts update when rules prop changes", () => {
    // REQUIREMENT: Severity counts must reflect the CURRENT rules prop,
    // not a stale snapshot from mount time.
    it("updates high_count when rules prop changes", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.high_count).toBe(1);

      const newRules = [
        ...stigRules,
        {
          id: 4,
          rule_id: "SV-204000r1_rule",
          version: "RHEL-08-010300",
          srg_id: "SRG-OS-000500",
          title: "Fourth",
          rule_severity: "high",
        },
      ];
      await wrapper.setProps({ rules: newRules });

      expect(wrapper.vm.high_count).toBe(2);
    });

    it("updates medium_count when rules prop changes", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.medium_count).toBe(1);

      const newRules = stigRules.filter((r) => r.rule_severity !== "medium");
      await wrapper.setProps({ rules: newRules });

      expect(wrapper.vm.medium_count).toBe(0);
    });

    it("updates low_count when rules prop changes", async () => {
      wrapper = createWrapper();
      expect(wrapper.vm.low_count).toBe(1);

      const newRules = [
        ...stigRules,
        {
          id: 5,
          rule_id: "SV-204001r1_rule",
          version: "RHEL-08-010400",
          srg_id: "SRG-OS-000600",
          title: "Fifth",
          rule_severity: "low",
        },
      ];
      await wrapper.setProps({ rules: newRules });

      expect(wrapper.vm.low_count).toBe(2);
    });
  });

  // ==========================================
  // SEVERITY FILTER
  // ==========================================
  describe("severity filtering", () => {
    it("filters by high severity", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ selectedSeverity: "high" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(1);
      expect(filtered[0].rule_severity).toBe("high");
    });

    it("shows all when severity is empty", async () => {
      wrapper = createWrapper();
      await wrapper.setData({ selectedSeverity: "" });
      const filtered = wrapper.vm.filteredRules;
      expect(filtered.length).toBe(3);
    });

    it("counts high severity rules", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.high_count).toBe(1);
    });

    it("counts medium severity rules", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.medium_count).toBe(1);
    });

    it("counts low severity rules", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.low_count).toBe(1);
    });
  });

  // ==========================================
  // RULE SELECTION
  // ==========================================
  describe("rule selection", () => {
    it("emits rule-selected when rule clicked", () => {
      wrapper = createWrapper();
      wrapper.vm.selectRule(stigRules[1]);
      expect(wrapper.emitted("rule-selected")).toBeTruthy();
      expect(wrapper.emitted("rule-selected")[0]).toEqual([stigRules[1]]);
    });

    it("highlights selected rule", () => {
      wrapper = createWrapper({ initialSelectedRule: stigRules[1] });
      expect(wrapper.vm.selectedRule).toEqual(stigRules[1]);
    });
  });

  // ==========================================
  // KEYBOARD NAVIGATION
  // ==========================================
  describe("keyboard navigation", () => {
    it("initializes focusedIndex as -1", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.focusedIndex).toBe(-1);
    });

    it("ArrowDown moves focus to next row", () => {
      wrapper = createWrapper();
      wrapper.vm.handleKeydown({ key: "ArrowDown", preventDefault: () => {} });
      expect(wrapper.vm.focusedIndex).toBe(0);
      wrapper.vm.handleKeydown({ key: "ArrowDown", preventDefault: () => {} });
      expect(wrapper.vm.focusedIndex).toBe(1);
    });

    it("ArrowUp moves focus to previous row", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = 2;
      wrapper.vm.handleKeydown({ key: "ArrowUp", preventDefault: () => {} });
      expect(wrapper.vm.focusedIndex).toBe(1);
    });

    it("ArrowDown wraps from last to first", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = stigRules.length - 1;
      wrapper.vm.handleKeydown({ key: "ArrowDown", preventDefault: () => {} });
      expect(wrapper.vm.focusedIndex).toBe(0);
    });

    it("ArrowUp wraps from first to last", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = 0;
      wrapper.vm.handleKeydown({ key: "ArrowUp", preventDefault: () => {} });
      expect(wrapper.vm.focusedIndex).toBe(stigRules.length - 1);
    });

    it("Enter selects the focused rule", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = 1;
      wrapper.vm.handleKeydown({ key: "Enter", preventDefault: () => {} });
      expect(wrapper.emitted("rule-selected")).toBeTruthy();
    });

    it("Space selects the focused rule", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = 0;
      wrapper.vm.handleKeydown({ key: " ", preventDefault: () => {} });
      expect(wrapper.emitted("rule-selected")).toBeTruthy();
    });
  });

  // ==========================================
  // ROW STYLING
  // ==========================================
  describe("row styling", () => {
    it("selected rule gets bg-secondary text-white", () => {
      wrapper = createWrapper();
      wrapper.vm.selectedRule = stigRules[0];
      expect(wrapper.vm.rowClass(stigRules[0], 0)).toBe("bg-secondary text-white");
    });

    it("focused but unselected row gets bg-light", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = 1;
      expect(wrapper.vm.rowClass(stigRules[1], 1)).toBe("bg-light");
    });

    it("unfocused unselected row gets empty string", () => {
      wrapper = createWrapper();
      wrapper.vm.focusedIndex = -1;
      expect(wrapper.vm.rowClass(stigRules[1], 1)).toBe("");
    });
  });

  // ==========================================
  // FILTER DROPDOWN MIGRATION (Task 28)
  // ==========================================
  describe("filter dropdown migration (Task 28)", () => {
    it("renders FilterDropdown for the field selector (not native <select>)", () => {
      wrapper = createWrapper();
      expect(wrapper.findComponent({ name: "FilterDropdown" }).exists()).toBe(true);
      expect(wrapper.find("select").exists()).toBe(false);
    });

    it("FilterDropdown is bound to `field` and exposes the type-specific options", () => {
      wrapper = createWrapper({ type: "stig" });
      const fd = wrapper.findComponent({ name: "FilterDropdown" });
      expect(fd.props("value")).toBe("rule_id");
      expect(fd.props("options")).toEqual([
        { value: "rule_id", text: "Rule ID" },
        { value: "stig_id", text: "STIG ID" },
        { value: "srg_id", text: "SRG ID" },
      ]);
    });
  });

  // ==========================================
  // ACCESSIBILITY
  // ==========================================
  describe("accessibility", () => {
    it("list container has listbox role", () => {
      wrapper = createWrapper();
      const listbox = wrapper.find("[role='listbox']");
      expect(listbox.exists()).toBe(true);
    });

    it("items have option role with aria-selected", () => {
      wrapper = createWrapper();
      const options = wrapper.findAll("[role='option']");
      options.wrappers.forEach((option) => {
        expect(option.attributes("aria-selected")).toBeDefined();
      });
    });
  });
});
