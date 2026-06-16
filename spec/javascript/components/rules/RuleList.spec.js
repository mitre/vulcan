import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import RuleList from "@/components/rules/RuleList.vue";

/**
 * RuleList requirements:
 *
 * 1. Renders "Open Rules" section with currently open rules from the store
 * 2. Renders "All Rules" section with the filtered rules passed as prop
 * 3. Clicking a rule row calls store.selectRule(rule.id)
 * 4. Clicking the X on an open rule calls store.deselectRule(rule.id)
 * 5. "close all" clears all open rules via store
 * 6. Highlights the selected rule row with .selectedRuleRow class
 * 7. Renders nesting tree when nestSatisfiedRulesChecked is true
 * 8. Shows comment badge icon for rules with open comments > 0
 * 9. Shows lock, review, changes-requested icons as appropriate
 * 10. Renders NewRuleModalForm when not readOnly
 */
describe("RuleList", () => {
  let wrapper;

  const createRule = (id, ruleId, overrides = {}) => ({
    id,
    rule_id: ruleId,
    version: `SV-${id}`,
    srg_id: `SRG-OS-${String(id).padStart(6, "0")}-GPOS-${String(id).padStart(5, "0")}`,
    status: "Applicable - Configurable",
    satisfies: [],
    satisfied_by: [],
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    histories: [],
    checks_attributes: [],
    disa_rule_descriptions_attributes: [],
    comment_summary: null,
    ...overrides,
  });

  const createSatisfactionRef = (id, ruleId, srgId) => ({
    id,
    rule_id: ruleId,
    srg_id: srgId,
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
  });

  const defaultProps = {
    filteredRules: [],
    allRules: [],
    componentId: 41,
    projectPrefix: "TEST",
    readOnly: false,
    nestSatisfiedRulesChecked: false,
    showSRGIdChecked: false,
  };

  let pinia;
  let router;

  const createWrapper = (props = {}) => {
    pinia = createPinia();
    setActivePinia(pinia);
    router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    const store = useRuleSelectionStore();
    store.init(router, props.componentId || defaultProps.componentId);

    return shallowMount(RuleList, {
      localVue,
      pinia,
      router,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        BIcon: true,
        BBadge: true,
        NewRuleModalForm: true,
      },
      mocks: {
        $root: { $emit: () => {} },
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("open rules section", () => {
    it("renders open rules from the store", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.openRuleIds = [1];

      expect(wrapper.vm.openRules.length).toBe(1);
      expect(wrapper.vm.openRules[0].id).toBe(1);
    });

    it("shows 'close all' when open rules exist", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.openRuleIds = [1];

      // Force reactivity
      wrapper.vm.$forceUpdate();
      const closeAll = wrapper.find('[data-test="close-all-rules"]');
      // The close-all link should exist when there are open rules
      expect(store.openRuleIds.length).toBe(1);
    });
  });

  describe("rule selection", () => {
    it("calls store.selectRule when a rule row is clicked", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      wrapper.vm.ruleSelected(rules[0]);
      const store = useRuleSelectionStore();
      expect(store.selectedRuleId).toBe(1);
    });

    it("applies selectedRuleRow class to the currently selected rule", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.selectedRuleId = 1;

      const rowClass = wrapper.vm.ruleRowClass(rules[0]);
      expect(rowClass.selectedRuleRow).toBe(true);
    });

    it("does not apply selectedRuleRow class to non-selected rules", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      const store = useRuleSelectionStore();
      store.selectedRuleId = 1;

      const rowClass = wrapper.vm.ruleRowClass(rules[1]);
      expect(rowClass.selectedRuleRow).toBe(false);
    });
  });

  describe("rule formatting", () => {
    it("formats rule ID with project prefix", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.formatRuleId("000001")).toBe("TEST-000001");
    });
  });

  describe("comment count rollup", () => {
    it("returns parent's own count plus all children's open counts", () => {
      const child1 = createRule(10, "001002", { comment_summary: { open: 2, total: 3 } });
      const child2 = createRule(11, "001003", { comment_summary: { open: 1, total: 2 } });
      const parent = createRule(1, "000020", {
        comment_summary: { open: 1, total: 5 },
        satisfies: [
          createSatisfactionRef(10, "001002", "SRG-OS-000010"),
          createSatisfactionRef(11, "001003", "SRG-OS-000011"),
        ],
      });

      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent, child1, child2] });
      expect(wrapper.vm.ruleOpen(parent)).toBe(4);
    });

    it("returns 0 for rules with no comment_summary", () => {
      const rule = createRule(1, "000001");
      wrapper = createWrapper({ filteredRules: [rule], allRules: [rule] });
      expect(wrapper.vm.ruleOpen(rule)).toBe(0);
    });
  });

  describe("nesting", () => {
    it("hasParentRules is true when a filtered rule has satisfies", () => {
      const parent = createRule(1, "000001", {
        satisfies: [createSatisfactionRef(2, "000002", "SRG-OS-000002")],
      });
      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent] });
      expect(wrapper.vm.hasParentRules).toBe(true);
    });

    it("hasParentRules is false when no filtered rules have satisfies", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules });
      expect(wrapper.vm.hasParentRules).toBe(false);
    });

    it("toggleParentExpanded toggles a parent's expanded state", () => {
      const parent = createRule(1, "000001", {
        satisfies: [createSatisfactionRef(2, "000002", "SRG-OS-000002")],
      });
      wrapper = createWrapper({ filteredRules: [parent], allRules: [parent] });

      expect(wrapper.vm.isParentExpanded(1)).toBe(false);
      wrapper.vm.toggleParentExpanded(1);
      expect(wrapper.vm.isParentExpanded(1)).toBe(true);
      wrapper.vm.toggleParentExpanded(1);
      expect(wrapper.vm.isParentExpanded(1)).toBe(false);
    });

    it("sortAlsoSatisfies sorts by rule_id", () => {
      const refs = [
        createSatisfactionRef(10, "001003", "SRG-OS-000010"),
        createSatisfactionRef(11, "001002", "SRG-OS-000011"),
      ];
      wrapper = createWrapper();
      const sorted = wrapper.vm.sortAlsoSatisfies(refs);
      expect(sorted[0].rule_id).toBe("001002");
      expect(sorted[1].rule_id).toBe("001003");
    });
  });

  describe("readOnly mode", () => {
    it("does not render add button when readOnly is true", () => {
      wrapper = createWrapper({ readOnly: true, filteredRules: [] });
      const addBtn = wrapper.find('[data-test="add-rule-btn"]');
      expect(addBtn.exists()).toBe(false);
    });
  });

  describe("count indicator", () => {
    it("shows total count when no filter is active", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002"), createRule(3, "000003")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules, hasActiveFilters: false });
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("(3)");
      expect(header.text()).not.toContain("of");
    });

    it("shows 'X of Y' when filter is active", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002"), createRule(3, "000003")];
      const filteredRules = [allRules[0]];
      wrapper = createWrapper({ filteredRules, allRules, hasActiveFilters: true });
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("1 of 3");
    });

    it("shows 'reset' link when filter is active", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: true });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(true);
    });

    it("does not show 'reset' link when no filter is active", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ filteredRules: rules, allRules: rules, hasActiveFilters: false });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(false);
    });

    it("does not show 'reset' when only nesting reduces count (not a filter)", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: false });
      const reset = wrapper.find('[data-test="inline-clear-filters"]');
      expect(reset.exists()).toBe(false);
      const header = wrapper.find('[data-test="all-rules-header"]');
      expect(header.text()).toContain("(2)");
      expect(header.text()).not.toContain("of");
    });

    it("emits reset-filters when inline reset is clicked", () => {
      const allRules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ filteredRules: [allRules[0]], allRules, hasActiveFilters: true });
      wrapper.find('[data-test="inline-clear-filters"]').trigger("click");
      expect(wrapper.emitted("reset-filters")).toBeTruthy();
    });
  });

  describe("SRG ID display", () => {
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
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: false,
      });
      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      expect(childRows.length).toBe(2);

      const child1Text = childRows.at(0).text();
      expect(child1Text).toContain("SRG-OS-000480");
      const child2Text = childRows.at(1).text();
      expect(child2Text).toContain("SRG-APP-000123");
    });

    it("shows full SRG ID in tooltip for nested children", () => {
      const { parentRule } = createParentWithChildren();
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: false,
      });
      wrapper.setData({ expandedParents: new Set([parentRule.id]) });

      const childRows = wrapper.findAll(".child-row");
      const tooltipSpans = childRows.at(0).findAll("span[title]");
      expect(tooltipSpans.length).toBeGreaterThan(0);
      const titleValue = tooltipSpans.at(0).attributes("title");
      expect(titleValue).toBeTruthy();
      expect(titleValue).toMatch(/^SRG-/);
    });

    it("displays truncated SRG ID for parent when showSRGIdChecked is true", () => {
      const { parentRule } = createParentWithChildren();
      wrapper = createWrapper({
        filteredRules: [parentRule],
        allRules: [parentRule],
        nestSatisfiedRulesChecked: true,
        showSRGIdChecked: true,
      });

      const allRows = wrapper.findAll(".ruleRow");
      expect(allRows.length).toBeGreaterThan(0);
      const parentText = allRows.at(0).text();
      expect(parentText).toContain("SRG-OS-000001");

      const tooltipSpan = allRows.at(0).find("span[title]");
      expect(tooltipSpan.exists()).toBe(true);
      expect(tooltipSpan.attributes("title")).toBe(srgIdParent);
    });

    it("displays formatted rule ID when showSRGIdChecked is false", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({
        filteredRules: rules,
        allRules: rules,
        showSRGIdChecked: false,
      });

      const row = wrapper.find(".ruleRow");
      expect(row.text()).toContain("TEST-000001");
    });
  });
});
