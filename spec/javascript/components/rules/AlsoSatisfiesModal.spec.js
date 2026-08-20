import { describe, it, expect, vi, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AlsoSatisfiesModal from "@/components/rules/AlsoSatisfiesModal.vue";

/**
 * AlsoSatisfiesModal requirements:
 *
 * A modal that lets the user multi-select rules to add as "also satisfies"
 * children of the currently selected rule.
 *
 * FILTERING:
 * 1. Excludes the currently selected rule from options
 * 2. Excludes rules that already satisfy other rules (satisfies.length > 0)
 * 3. Excludes rules already in the selected rule's satisfies list
 *
 * DISPLAY:
 * 4. Shows both SRG ID and Rule ID in option text
 * 5. Falls back to prefix-rule_id when srg_id is null
 * 6. Toggle switches between SRG ID-first and Rule ID-first display
 *
 * ACTIONS:
 * 7. Emits add-satisfied for each selected rule when confirmed
 * 8. Clears selection when modal is hidden
 */
describe("AlsoSatisfiesModal", () => {
  let wrapper;

  const rulesWithSrgIds = [
    {
      id: 1,
      rule_id: "001",
      srg_id: "SRG-OS-000001-GPOS-00001",
      status: "Applicable - Configurable",
      satisfies: [],
      satisfied_by: [],
    },
    {
      id: 2,
      rule_id: "002",
      srg_id: "SRG-OS-000002-GPOS-00002",
      status: "Not Yet Determined",
      satisfies: [],
      satisfied_by: [],
    },
    {
      id: 3,
      rule_id: "003",
      srg_id: "SRG-OS-000003-GPOS-00003",
      status: "Applicable - Configurable",
      satisfies: [{ id: 99, rule_id: "099", srg_id: "SRG-OS-000099-GPOS-00099" }],
      satisfied_by: [],
    },
    {
      id: 4,
      rule_id: "004",
      srg_id: null,
      status: "Not Applicable",
      satisfies: [],
      satisfied_by: [],
    },
  ];

  const defaultProps = {
    rules: rulesWithSrgIds,
    selectedRule: rulesWithSrgIds[0],
    componentPrefix: "TEST",
    showSRGIdChecked: false,
  };

  const createWrapper = (props = {}) => {
    return shallowMount(AlsoSatisfiesModal, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BModal: true,
        BFormCheckbox: true,
        BFormGroup: true,
        BBadge: true,
        BIcon: true,
        BButton: true,
        Multiselect: true,
      },
      mocks: {
        $root: { $emit: vi.fn() },
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("filtering eligible rules", () => {
    it("excludes the currently selected rule from options", () => {
      wrapper = createWrapper();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).not.toContain(1);
    });

    it("excludes rules that already satisfy other rules", () => {
      wrapper = createWrapper();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).not.toContain(3);
    });

    it("excludes rules already in the selected rule's satisfies list", () => {
      const selectedWithExisting = {
        ...rulesWithSrgIds[0],
        satisfies: [{ id: 2, rule_id: "002", srg_id: "SRG-OS-000002-GPOS-00002" }],
      };
      wrapper = createWrapper({ selectedRule: selectedWithExisting });
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).not.toContain(2);
    });

    it("includes eligible rules", () => {
      wrapper = createWrapper();
      const ids = wrapper.vm.filteredSelectRules.map((r) => r.value);
      expect(ids).toContain(2);
      expect(ids).toContain(4);
    });

    it("returns empty when selectedRule is null", () => {
      wrapper = createWrapper({ selectedRule: null });
      expect(wrapper.vm.filteredSelectRules).toEqual([]);
    });
  });

  describe("display format", () => {
    it("displays SRG ID first by default", () => {
      wrapper = createWrapper();
      const rule2Option = wrapper.vm.filteredSelectRules.find((r) => r.value === 2);
      expect(rule2Option.text).toContain("SRG-OS-000002");
      expect(rule2Option.text).toContain("TEST-002");
    });

    it("falls back to prefix-rule_id when srg_id is null", () => {
      wrapper = createWrapper();
      const rule4Option = wrapper.vm.filteredSelectRules.find((r) => r.value === 4);
      expect(rule4Option.text).toContain("TEST-004");
    });

    it("displays Rule ID first when showRuleId toggle is on", () => {
      wrapper = createWrapper();
      wrapper.setData({ showRuleId: true });
      const rule2Option = wrapper.vm.filteredSelectRules.find((r) => r.value === 2);
      expect(rule2Option.text).toMatch(/^TEST-002/);
    });
  });

  describe("actions", () => {
    it("emits add-satisfied for each selected rule when confirmed", () => {
      wrapper = createWrapper();
      wrapper.setData({
        selectedRuleIds: [
          { value: 2, text: "SRG-OS-000002" },
          { value: 4, text: "TEST-004" },
        ],
      });
      wrapper.vm.addMultipleSatisfiedRules();
      expect(wrapper.emitted("add-satisfied")).toHaveLength(2);
      expect(wrapper.emitted("add-satisfied")[0]).toEqual([2, 1]);
      expect(wrapper.emitted("add-satisfied")[1]).toEqual([4, 1]);
    });

    it("does nothing when no rule is selected", () => {
      wrapper = createWrapper({ selectedRule: null });
      wrapper.setData({ selectedRuleIds: [{ value: 2, text: "SRG-OS-000002" }] });
      wrapper.vm.addMultipleSatisfiedRules();
      expect(wrapper.emitted("add-satisfied")).toBeFalsy();
    });

    it("clears selection when clearSelectedRules is called", () => {
      wrapper = createWrapper();
      wrapper.setData({ selectedRuleIds: [{ value: 2, text: "SRG-OS-000002" }] });
      wrapper.vm.clearSelectedRules();
      expect(wrapper.vm.selectedRuleIds).toEqual([]);
    });
  });
});
