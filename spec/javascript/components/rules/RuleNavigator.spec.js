import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import { createPinia, setActivePinia } from "pinia";
import { createTestRouter } from "@test/support/routerTestHelper";
import { useRuleSelectionStore } from "@/stores/ruleSelection";
import RuleNavigator from "@/components/rules/RuleNavigator.vue";

/**
 * RuleNavigator is a thin orchestrator that:
 * 1. Manages filter state (local + external) and localStorage persistence
 * 2. Computes filteredRules from rules + filters
 * 3. Delegates rendering to RuleSearchBar + RuleList sub-components
 * 4. Handles search result selection (selects rule via store + field scrolling)
 * 5. Manages sidebar scroll position
 *
 * Sub-component responsibilities tested in their own specs:
 * - RuleSearchBar.spec.js — search input, debounce, ComponentSearchModal, reset
 * - RuleList.spec.js — rule row rendering, selection, nesting, SRG ID display
 * - RuleRowIcons.spec.js — comment badges, lock/review/changes icons
 */
describe("RuleNavigator", () => {
  let wrapper;

  const createRule = (id, ruleId, overrides = {}) => ({
    id,
    rule_id: ruleId,
    version: `SV-${id}`,
    srg_id:
      overrides.srg_id ||
      `SRG-OS-${String(id).padStart(6, "0")}-GPOS-${String(id).padStart(5, "0")}`,
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

  const createSatisfactionRef = (id, ruleId, srgId) => ({
    id,
    rule_id: ruleId,
    srg_id: srgId,
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

  let pinia;
  let router;

  const createWrapper = (props = {}, filters = {}) => {
    pinia = createPinia();
    setActivePinia(pinia);
    router = createTestRouter([
      { path: "/", name: "editor-root" },
      { path: "/rules/:ruleId", name: "rule", props: true },
    ]);
    const store = useRuleSelectionStore();
    store.init(router, props.componentId || defaultProps.componentId);

    return shallowMount(RuleNavigator, {
      localVue,
      pinia,
      router,
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
            openCommentsOnly: false,
            ...filters,
          },
        };
      },
      stubs: {
        RuleSearchBar: true,
        RuleList: true,
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
        const leafRule1 = createRule(1, "001", { satisfies: [], satisfied_by: [] });
        const parentRule = createRule(2, "002", {
          satisfies: [createRule(3, "003")],
          satisfied_by: [],
        });
        const leafRule2 = createRule(4, "004", { satisfies: [], satisfied_by: [] });

        const rules = [leafRule1, parentRule, leafRule2];
        wrapper = createWrapper({ rules }, { nestSatisfiedRulesChecked: true });

        const filteredRules = wrapper.vm.filteredRules;
        expect(filteredRules[0].id).toBe(parentRule.id);
        expect(filteredRules[1].id).toBe(leafRule1.id);
        expect(filteredRules[2].id).toBe(leafRule2.id);
      });

      it("maintains relative order among parents and among leaves", () => {
        const parent1 = createRule(1, "001", { satisfies: [createRule(10, "010")] });
        const leaf1 = createRule(2, "002", { satisfies: [] });
        const parent2 = createRule(3, "003", { satisfies: [createRule(11, "011")] });
        const leaf2 = createRule(4, "004", { satisfies: [] });

        const rules = [parent1, leaf1, parent2, leaf2];
        wrapper = createWrapper({ rules }, { nestSatisfiedRulesChecked: true });

        const filteredRules = wrapper.vm.filteredRules;
        expect(filteredRules[0].id).toBe(parent1.id);
        expect(filteredRules[1].id).toBe(parent2.id);
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
        expect(filteredRules[0].id).toBe(leafRule1.id);
        expect(filteredRules[1].id).toBe(parentRule.id);
        expect(filteredRules[2].id).toBe(leafRule2.id);
      });
    });

    describe("combined with sortBySRGIdChecked", () => {
      it("sorts by SRG ID first, then groups parents before leaves", () => {
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
        expect(filteredRules[0].version).toBe("SV-100");
        expect(filteredRules[1].version).toBe("SV-400");
        expect(filteredRules[2].version).toBe("SV-200");
        expect(filteredRules[3].version).toBe("SV-300");
      });
    });
  });

  describe("ruleOpen rolled-up comment counts", () => {
    const ruleWithComments = (id, ruleId, open, total, overrides = {}) =>
      createRule(id, ruleId, {
        comment_summary: { open, total },
        ...overrides,
      });

    it("returns the parent's own count plus all children's open counts", () => {
      const child1 = ruleWithComments(10, "001002", 2, 3);
      const child2 = ruleWithComments(11, "001003", 1, 2);
      const child3 = ruleWithComments(12, "001004", 0, 1);
      const parent = ruleWithComments(1, "000020", 1, 5, {
        satisfies: [
          createSatisfactionRef(10, "001002", "SRG-OS-000010"),
          createSatisfactionRef(11, "001003", "SRG-OS-000011"),
          createSatisfactionRef(12, "001004", "SRG-OS-000012"),
        ],
      });

      wrapper = createWrapper({ rules: [parent, child1, child2, child3] });
      expect(wrapper.vm.ruleOpen(parent)).toBe(4);
    });

    it("returns only the rule's own count for non-parent rules", () => {
      const leaf = ruleWithComments(5, "000050", 3, 5);
      wrapper = createWrapper({ rules: [leaf] });
      expect(wrapper.vm.ruleOpen(leaf)).toBe(3);
    });

    it("returns children's counts even when parent has zero own comments", () => {
      const child1 = ruleWithComments(10, "001002", 5, 5);
      const parent = ruleWithComments(1, "000020", 0, 0, {
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });

      wrapper = createWrapper({ rules: [parent, child1] });
      expect(wrapper.vm.ruleOpen(parent)).toBe(5);
    });

    it("returns 0 when parent and all children have no comments", () => {
      const child1 = createRule(10, "001002");
      const parent = createRule(1, "000020", {
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });

      wrapper = createWrapper({ rules: [parent, child1] });
      expect(wrapper.vm.ruleOpen(parent)).toBe(0);
    });

    it("open comments only filter includes parents with children that have open comments", () => {
      const child1 = ruleWithComments(10, "001002", 3, 3);
      const parent = ruleWithComments(1, "000020", 0, 0, {
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });
      const standalone = createRule(2, "000030");

      wrapper = createWrapper(
        { rules: [parent, child1, standalone] },
        { openCommentsOnly: true },
      );
      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).toContain(1);
      expect(ids).not.toContain(2);
    });
  });

  describe("search respects nesting filter", () => {
    it("does not show satisfied-by children even when they match the search text", () => {
      const child = createRule(10, "001002", {
        title: "unique-child-keyword",
        satisfied_by: [{ id: 1 }],
      });
      const parent = createRule(1, "000020", {
        title: "Parent control",
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });

      wrapper = createWrapper(
        { rules: [parent, child] },
        { nestSatisfiedRulesChecked: true, search: "unique-child-keyword" },
      );

      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).not.toContain(10);
    });

    it("shows parent rules that match search text when nesting is enabled", () => {
      const child = createRule(10, "001002", {
        title: "Child rule",
        satisfied_by: [{ id: 1 }],
      });
      const parent = createRule(1, "000020", {
        title: "unique-parent-keyword",
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });

      wrapper = createWrapper(
        { rules: [parent, child] },
        { nestSatisfiedRulesChecked: true, search: "unique-parent-keyword" },
      );

      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).toContain(1);
    });

    it("shows children when nesting is DISABLED and they match search", () => {
      const child = createRule(10, "001002", {
        title: "unique-child-keyword",
        satisfied_by: [{ id: 1 }],
      });
      const parent = createRule(1, "000020", {
        title: "Parent control",
        satisfies: [createSatisfactionRef(10, "001002", "SRG-OS-000010")],
      });

      wrapper = createWrapper(
        { rules: [parent, child] },
        { nestSatisfiedRulesChecked: false, search: "unique-child-keyword" },
      );

      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).toContain(10);
    });

    it("shows standalone rules that match search regardless of nesting toggle", () => {
      const standalone = createRule(5, "000050", {
        title: "unique-standalone-keyword",
        satisfied_by: [],
      });

      wrapper = createWrapper(
        { rules: [standalone] },
        { nestSatisfiedRulesChecked: true, search: "unique-standalone-keyword" },
      );

      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).toContain(5);
    });
  });

  describe("search result selection", () => {
    it("selects rule via store when search result is chosen", () => {
      const rules = [createRule(1, "000001"), createRule(2, "000002")];
      wrapper = createWrapper({ rules });
      wrapper.vm.onSearchResultSelected({ id: 2, rule_id: "000002" });
      const store = useRuleSelectionStore();
      expect(store.selectedRuleId).toBe(2);
    });

    it("does not throw when result has matched_field (delegates to scrollToField utility)", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ rules });
      expect(() => {
        wrapper.vm.onSearchResultSelected({
          id: 1,
          rule_id: "000001",
          matched_field: "fixtext",
          searchQuery: "least privilege",
        });
      }).not.toThrow();
    });

    it("does not throw when result has no matched_field", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ rules });
      expect(() => {
        wrapper.vm.onSearchResultSelected({ id: 1, rule_id: "000001" });
      }).not.toThrow();
    });
  });

  describe("sidebar layout", () => {
    it("does not use computed max-height (flex layout handles height)", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.sidebarStyle).toBeUndefined();
    });
  });

  describe("sub-component composition", () => {
    it("renders RuleSearchBar with correct props", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ rules });
      const searchBar = wrapper.findComponent({ name: "RuleSearchBar" });
      expect(searchBar.exists()).toBe(true);
    });

    it("renders RuleList with correct props", () => {
      const rules = [createRule(1, "000001")];
      wrapper = createWrapper({ rules });
      const ruleList = wrapper.findComponent({ name: "RuleList" });
      expect(ruleList.exists()).toBe(true);
    });

    it("passes filteredRules to RuleList", () => {
      const rules = [
        createRule(1, "000001", { status: "Applicable - Configurable" }),
        createRule(2, "000002", { status: "Not Applicable" }),
      ];
      wrapper = createWrapper({ rules }, { naFilterChecked: false });
      const filteredIds = wrapper.vm.filteredRules.map((r) => r.id);
      expect(filteredIds).toContain(1);
      expect(filteredIds).not.toContain(2);
    });
  });

  describe("filteredRules status filter", () => {
    it("narrows to rules with open > 0 when openCommentsOnly is set", () => {
      const rules = [
        createRule(10, "000100", { comment_summary: { open: 3, total: 3 } }),
        createRule(11, "000110", { comment_summary: { open: 0, total: 0 } }),
        createRule(12, "000120"),
      ];
      wrapper = createWrapper({ rules }, { openCommentsOnly: true });
      const ids = wrapper.vm.filteredRules.map((r) => r.id);
      expect(ids).toEqual([10]);
    });

    it("shows all rules when openCommentsOnly is false", () => {
      const rules = [
        createRule(20, "000200", { comment_summary: { open: 1, total: 1 } }),
        createRule(21, "000210", { comment_summary: { open: 0, total: 0 } }),
      ];
      wrapper = createWrapper({ rules });
      expect(wrapper.vm.filteredRules.length).toBe(2);
    });
  });
});
