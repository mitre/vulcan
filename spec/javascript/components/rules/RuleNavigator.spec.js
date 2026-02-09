import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleNavigator from "@/components/rules/RuleNavigator.vue";

/**
 * RuleNavigator filtering/sorting requirements:
 *
 * When nestSatisfiedRulesChecked is true:
 * - Parent rules (satisfies.length > 0) should appear BEFORE leaf rules
 * - This allows the collapsible tree to show parents at top level
 * - Leaves that are "satisfied by" other rules are hidden from main list
 *   (they appear nested under their parent)
 */
describe("RuleNavigator", () => {
  let wrapper;

  const createRule = (id, ruleId, overrides = {}) => ({
    id,
    rule_id: ruleId,
    version: `SV-${id}`,
    status: "Applicable - Configurable",
    satisfies: [],
    satisfied_by: [],
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    histories: [],
    checks_attributes: [],
    disa_rule_descriptions_attributes: [],
    ...overrides,
  });

  const defaultProps = {
    componentId: 41,
    projectPrefix: "TEST",
    rules: [],
    openRuleIds: [],
    readOnly: false,
  };

  const createWrapper = (props = {}, filters = {}) => {
    return shallowMount(RuleNavigator, {
      localVue,
      propsData: {
        ...defaultProps,
        ...props,
      },
      data() {
        return {
          localFilters: {
            search: "",
            acFilterChecked: true,
            aimFilterChecked: true,
            adnmFilterChecked: true,
            naFilterChecked: true,
            nydFilterChecked: true,
            nurFilterChecked: true,
            urFilterChecked: true,
            lckFilterChecked: true,
            nestSatisfiedRulesChecked: true,
            showSRGIdChecked: false,
            sortBySRGIdChecked: true,
            ...filters,
          },
          expandedParents: new Set(),
        };
      },
      stubs: {
        BIcon: true,
        BBadge: true,
        BModal: true,
        FindAndReplace: true,
        NewRuleModalForm: true,
      },
      mocks: {
        $root: {
          $emit: () => {},
        },
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("filterRules sorting", () => {
    describe("when nestSatisfiedRulesChecked is true", () => {
      it("sorts parents (satisfies.length > 0) before leaves", () => {
        // Create rules: some are parents (have satisfies), some are leaves
        const leafRule1 = createRule(1, "001", { satisfies: [], satisfied_by: [] });
        const parentRule = createRule(2, "002", {
          satisfies: [createRule(3, "003")], // This rule satisfies another
          satisfied_by: [],
        });
        const leafRule2 = createRule(4, "004", { satisfies: [], satisfied_by: [] });

        // Rules in mixed order: leaf, parent, leaf
        const rules = [leafRule1, parentRule, leafRule2];

        wrapper = createWrapper({ rules }, { nestSatisfiedRulesChecked: true });

        const filteredRules = wrapper.vm.filteredRules;

        // Parent should come first
        expect(filteredRules[0].id).toBe(parentRule.id);
        // Leaves should come after
        expect(filteredRules[1].id).toBe(leafRule1.id);
        expect(filteredRules[2].id).toBe(leafRule2.id);
      });

      it("maintains relative order among parents and among leaves", () => {
        const parent1 = createRule(1, "001", { satisfies: [createRule(10, "010")] });
        const leaf1 = createRule(2, "002", { satisfies: [] });
        const parent2 = createRule(3, "003", { satisfies: [createRule(11, "011")] });
        const leaf2 = createRule(4, "004", { satisfies: [] });

        // Mixed order: parent1, leaf1, parent2, leaf2
        const rules = [parent1, leaf1, parent2, leaf2];

        wrapper = createWrapper({ rules }, { nestSatisfiedRulesChecked: true });

        const filteredRules = wrapper.vm.filteredRules;

        // Parents first, in their original relative order
        expect(filteredRules[0].id).toBe(parent1.id);
        expect(filteredRules[1].id).toBe(parent2.id);
        // Leaves after, in their original relative order
        expect(filteredRules[2].id).toBe(leaf1.id);
        expect(filteredRules[3].id).toBe(leaf2.id);
      });
    });

    describe("when nestSatisfiedRulesChecked is false", () => {
      it("does not sort parents before leaves", () => {
        const leafRule1 = createRule(1, "001", { satisfies: [] });
        const parentRule = createRule(2, "002", { satisfies: [createRule(3, "003")] });
        const leafRule2 = createRule(4, "004", { satisfies: [] });

        const rules = [leafRule1, parentRule, leafRule2];

        wrapper = createWrapper({ rules }, { nestSatisfiedRulesChecked: false });

        const filteredRules = wrapper.vm.filteredRules;

        // Order should remain as-is (no parent-first sorting)
        expect(filteredRules[0].id).toBe(leafRule1.id);
        expect(filteredRules[1].id).toBe(parentRule.id);
        expect(filteredRules[2].id).toBe(leafRule2.id);
      });
    });

    describe("combined with sortBySRGIdChecked", () => {
      it("sorts by SRG ID first, then groups parents before leaves", () => {
        // Create rules with specific versions for SRG ID sorting
        const leaf_v3 = createRule(1, "001", { version: "SV-300", satisfies: [] });
        const parent_v1 = createRule(2, "002", {
          version: "SV-100",
          satisfies: [createRule(10, "010")],
        });
        const leaf_v2 = createRule(3, "003", { version: "SV-200", satisfies: [] });
        const parent_v4 = createRule(4, "004", {
          version: "SV-400",
          satisfies: [createRule(11, "011")],
        });

        const rules = [leaf_v3, parent_v1, leaf_v2, parent_v4];

        wrapper = createWrapper(
          { rules },
          { nestSatisfiedRulesChecked: true, sortBySRGIdChecked: true },
        );

        const filteredRules = wrapper.vm.filteredRules;

        // When both sorts active: SRG ID sort happens first, then parent-first grouping
        // Expected: parents first (sorted by version), then leaves (sorted by version)
        expect(filteredRules[0].version).toBe("SV-100"); // parent_v1
        expect(filteredRules[1].version).toBe("SV-400"); // parent_v4
        expect(filteredRules[2].version).toBe("SV-200"); // leaf_v2
        expect(filteredRules[3].version).toBe("SV-300"); // leaf_v3
      });
    });
  });
});
