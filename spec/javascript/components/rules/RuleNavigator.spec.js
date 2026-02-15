import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleNavigator from "@/components/rules/RuleNavigator.vue";

/**
 * RuleNavigator requirements:
 *
 * FILTERING/SORTING:
 * - When nestSatisfiedRulesChecked is true, parent rules (satisfies.length > 0)
 *   appear BEFORE leaf rules
 * - Leaves "satisfied by" other rules are hidden from the main list
 *   (they appear nested under their parent)
 *
 * SRG ID DISPLAY (CRITICAL):
 * - When showSRGIdChecked is true, ALL items display SRG requirement IDs
 * - Parent rules display via rule.version (which IS the SRG ID for Component Rules)
 * - Nested satisfaction children display via satisfies.srg_id (from as_json serialization)
 * - Backend serializes satisfaction objects as: { id, rule_id, srg_id }
 *   They do NOT include a 'version' field — srg_id is the correct field
 * - When showSRGIdChecked is false, all items display formatted rule IDs (prefix-rule_id)
 */
describe("RuleNavigator", () => {
  let wrapper;

  const createRule = (id, ruleId, overrides = {}) => ({
    id,
    rule_id: ruleId,
    version: `SV-${id}`,
    srg_id: overrides.srg_id || `SRG-OS-${String(id).padStart(6, "0")}-GPOS-${String(id).padStart(5, "0")}`,
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

  /**
   * Creates a satisfaction child reference matching the ACTUAL backend serialization.
   * Backend as_json produces: { id, rule_id, srg_id } — NO version field.
   * This is the data shape the template MUST work with.
   */
  const createSatisfactionRef = (id, ruleId, srgId) => ({
    id,
    rule_id: ruleId,
    srg_id: srgId,
    // Intentionally NO version field — matches real as_json serialization
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
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

  // ===========================================================================
  // REQUIREMENT: Satisfaction nested children must display SRG IDs when
  // showSRGIdChecked is true. The srg_id field comes from the backend
  // serialization (as_json) which maps it from srg_rule.version.
  //
  // This was a P0 REGRESSION: children displayed empty strings because
  // the template used `satisfies.version` which doesn't exist in the
  // serialization. The correct field is `satisfies.srg_id`.
  // ===========================================================================
  describe("satisfaction nested children SRG ID display", () => {
    const srgIdParent = "SRG-OS-000001-GPOS-00001";
    const srgIdChild1 = "SRG-OS-000480-GPOS-00227";
    const srgIdChild2 = "SRG-APP-000123-GPOS-00456";

    const createParentWithChildren = () => {
      const child1 = createSatisfactionRef(10, "001002", srgIdChild1);
      const child2 = createSatisfactionRef(11, "001003", srgIdChild2);
      const parentRule = createRule(1, "000020", {
        version: srgIdParent,
        srg_id: srgIdParent,
        satisfies: [child1, child2],
      });
      return { parentRule, child1, child2 };
    };

    it("ALWAYS displays SRG IDs for nested children regardless of toggle", () => {
      const { parentRule } = createParentWithChildren();

      // showSRGIdChecked is FALSE — but nested children ALWAYS show SRG IDs
      // WHY: These represent SRG requirements, not STIG rules
      wrapper = createWrapper(
        { rules: [parentRule] },
        { nestSatisfiedRulesChecked: true, showSRGIdChecked: false },
      );

      // Expand the parent to reveal nested children
      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      expect(childRows.length).toBe(2);

      // Children sorted by rule_id: 001002 (SRG-OS-000480) < 001003 (SRG-APP-000123)
      const child1Text = childRows.at(0).text();
      expect(child1Text).toContain("SRG-OS-000480");
      const child2Text = childRows.at(1).text();
      expect(child2Text).toContain("SRG-APP-000123");

      // Must NOT show formatted rule IDs — always SRG IDs
      expect(child1Text).not.toContain("TEST-001");
      expect(child2Text).not.toContain("TEST-001");
    });

    it("shows full SRG ID in tooltip for nested children", () => {
      const { parentRule } = createParentWithChildren();

      wrapper = createWrapper(
        { rules: [parentRule] },
        { nestSatisfiedRulesChecked: true, showSRGIdChecked: false },
      );

      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      // Find span with title attribute (tooltip shows full SRG ID)
      const tooltipSpans = childRows.at(0).findAll("span[title]");
      expect(tooltipSpans.length).toBeGreaterThan(0);

      // Tooltip should contain a full SRG ID, not be empty or undefined
      const titleValue = tooltipSpans.at(0).attributes("title");
      expect(titleValue).toBeTruthy();
      expect(titleValue).toMatch(/^SRG-/);
    });

    it("displays truncated SRG ID for parent rule when showSRGIdChecked is true", () => {
      const { parentRule } = createParentWithChildren();

      wrapper = createWrapper(
        { rules: [parentRule] },
        { nestSatisfiedRulesChecked: true, showSRGIdChecked: true },
      );

      // Find the parent rule row (not a child-row)
      const allRows = wrapper.findAll(".ruleRow");
      expect(allRows.length).toBeGreaterThan(0);

      // Parent should display truncated SRG ID (truncateId removes -GPOS-##### suffix)
      const parentText = allRows.at(0).text();
      expect(parentText).toContain("SRG-OS-000001");

      // Full SRG ID should be in tooltip
      const tooltipSpan = allRows.at(0).find("span[title]");
      expect(tooltipSpan.exists()).toBe(true);
      expect(tooltipSpan.attributes("title")).toBe(srgIdParent);
    });
  });

  // ===========================================================================
  // REQUIREMENT: Satisfaction data shape contract.
  // The satisfaction objects in a rule's satisfies/satisfied_by arrays
  // must work correctly with the compact serialization from as_json:
  // { id, rule_id, srg_id } — no version field.
  // ===========================================================================
  describe("satisfaction data shape contract", () => {
    it("works with satisfaction objects that have srg_id but no version field", () => {
      // This matches the REAL serialization from Rule#as_json
      const satisfactionRef = createSatisfactionRef(10, "001002", "SRG-OS-000480-GPOS-00227");

      // Verify the test helper produces the correct shape
      expect(satisfactionRef).toHaveProperty("srg_id");
      expect(satisfactionRef).not.toHaveProperty("version");
      expect(satisfactionRef.srg_id).toBe("SRG-OS-000480-GPOS-00227");
    });

    it("sortAlsoSatisfies works with compact satisfaction objects", () => {
      const child1 = createSatisfactionRef(10, "001003", "SRG-OS-000480-GPOS-00227");
      const child2 = createSatisfactionRef(11, "001002", "SRG-APP-000123-GPOS-00456");
      const parentRule = createRule(1, "000020", {
        satisfies: [child1, child2],
      });

      wrapper = createWrapper({ rules: [parentRule] });

      // sortAlsoSatisfies should sort by rule_id
      const sorted = wrapper.vm.sortAlsoSatisfies(parentRule.satisfies);
      expect(sorted[0].rule_id).toBe("001002");
      expect(sorted[1].rule_id).toBe("001003");
    });
  });
});
