import { describe, it, expect, vi, beforeEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import Rules from "@/components/rules/Rules.vue";
vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(() => Promise.resolve({ data: {} })),
    post: vi.fn(() => Promise.resolve({ data: {} })),
    put: vi.fn(() => Promise.resolve({ data: {} })),
    patch: vi.fn(() => Promise.resolve({ data: {} })),
    delete: vi.fn(() => Promise.resolve({ data: {} })),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/rulesApi", () => ({
  getRule: vi.fn(() => Promise.resolve({ data: {} })),
  deleteRule: vi.fn(() => Promise.resolve({ data: {} })),
  createRuleInComponent: vi.fn(() => Promise.resolve({ data: {} })),
  addSatisfaction: vi.fn(() => Promise.resolve({ data: {} })),
  removeSatisfaction: vi.fn(() => Promise.resolve({ data: {} })),
}));

vi.mock("@/composables/useSortRules", { spy: true });
import { useSortRules } from "@/composables/useSortRules";

describe("Rules", () => {
  const createWrapper = (rulesOverrides = []) => {
    const defaultRule = {
      id: 1,
      component_id: 100,
      rule_id: "000010",
      version: "APSC-DV-000010",
      status: "Not Yet Determined",
      satisfied_by: [],
      satisfies: [],
      disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
      checks_attributes: [{ content: "" }],
      rule_descriptions_attributes: [],
    };

    const rules = rulesOverrides.length > 0 ? rulesOverrides : [defaultRule];

    return shallowMount(Rules, {
      localVue,
      propsData: {
        effective_permissions: "admin",
        current_user_id: 1,
        project: { id: 1, name: "Test Project" },
        component: { id: 100, name: "Test Component", version: "1", release: "1" },
        rules: rules,
        statuses: ["Not Yet Determined", "Applicable - Configurable"],
        available_roles: ["viewer", "author", "reviewer", "admin"],
      },
    });
  };

  describe("viewport-locked layout", () => {
    it("root element has vulcan-editor-layout class for flex chain continuity", () => {
      const wrapper = createWrapper();
      expect(wrapper.classes()).toContain("vulcan-editor-layout");
      wrapper.destroy();
    });
  });

  // ── composable contracts ────────────────────────────────────────────
  // REQUIREMENT: the initial rule list sorts by rule_id via useSortRules
  // (setup-before-data — data() reads this.compareRules). FormMixin was
  // verified dead and removed; AlertMixin stays until the toast migration.
  describe("composable contracts", () => {
    beforeEach(() => vi.clearAllMocks());

    it("sorts the initial rules by rule_id via useSortRules", () => {
      const base = {
        component_id: 100,
        status: "Not Yet Determined",
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [],
        checks_attributes: [],
        rule_descriptions_attributes: [],
      };
      const wrapper = createWrapper([
        { ...base, id: 3, rule_id: "000030" },
        { ...base, id: 1, rule_id: "000010" },
        { ...base, id: 2, rule_id: "000020" },
      ]);
      expect(useSortRules).toHaveBeenCalled();
      expect(wrapper.vm.reactiveRules.map((r) => r.rule_id)).toEqual([
        "000010",
        "000020",
        "000030",
      ]);
      wrapper.destroy();
    });
  });

  describe("addSatisfiedRule", () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it("preserves unsaved local changes when adding satisfaction", async () => {
      // Setup: Create two rules - one will satisfy the other
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: "000010",
        version: "APSC-DV-000010",
        status: "Not Yet Determined",
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: "000020",
        version: "APSC-DV-000020",
        status: "Applicable - Configurable",
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };

      const wrapper = createWrapper([rule1, rule2]);

      // Simulate local status change (user changes status but hasn't saved yet)
      wrapper.vm.reactiveRules[0].status = "Applicable - Configurable";

      const { addSatisfaction, getRule } = await import("@/api/rulesApi");
      addSatisfaction.mockResolvedValue({
        data: { toast: "Successfully marked as satisfied" },
      });

      getRule.mockResolvedValue({
        data: {
          id: 1,
          component_id: 100,
          rule_id: "000010",
          version: "APSC-DV-000010",
          status: "Not Yet Determined", // Server still has old status
          satisfied_by: [rule2], // But now has the satisfaction
          satisfies: [],
          disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
          checks_attributes: [{ content: "" }],
          rule_descriptions_attributes: [],
        },
      });

      // Act: Add satisfaction (rule1 is satisfied by rule2)
      await wrapper.vm.addSatisfiedRule(1, 2);

      // Wait for promises to resolve
      await wrapper.vm.$nextTick();
      await new Promise((resolve) => setTimeout(resolve, 10));

      // Assert: Local status change should be PRESERVED
      // This is the key assertion - the bug is that this currently fails
      // because refreshRule overwrites local changes with server data
      expect(wrapper.vm.reactiveRules[0].status).toBe("Applicable - Configurable");

      // Also verify the satisfaction was added
      expect(wrapper.vm.reactiveRules[0].satisfied_by.length).toBe(1);
    });

    it("updates satisfaction arrays without full rule refresh", async () => {
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: "000010",
        version: "APSC-DV-000010",
        status: "Applicable - Configurable",
        title: "Local unsaved title change", // Local change
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: "000020",
        version: "APSC-DV-000020",
        status: "Applicable - Configurable",
        satisfied_by: [],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };

      const wrapper = createWrapper([rule1, rule2]);

      const { addSatisfaction } = await import("@/api/rulesApi");
      addSatisfaction.mockResolvedValue({
        data: {
          toast: "Successfully marked as satisfied",
          rule: { ...rule1, satisfied_by: [rule2] },
          satisfied_by_rule: { ...rule2, satisfies: [rule1] },
        },
      });

      // Call addSatisfiedRule
      await wrapper.vm.addSatisfiedRule(1, 2);
      await wrapper.vm.$nextTick();

      // Local changes should be preserved
      expect(wrapper.vm.reactiveRules[0].title).toBe("Local unsaved title change");
    });
  });

  describe("removeSatisfiedRule", () => {
    beforeEach(() => {
      vi.clearAllMocks();
    });

    it("preserves unsaved local changes when removing satisfaction", async () => {
      // Setup: rule1 is satisfied by rule2
      const rule1 = {
        id: 1,
        component_id: 100,
        rule_id: "000010",
        version: "APSC-DV-000010",
        status: "Applicable - Configurable",
        satisfied_by: [{ id: 2, rule_id: "000020", srg_id: "SRG-OS-000020" }],
        satisfies: [],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };
      const rule2 = {
        id: 2,
        component_id: 100,
        rule_id: "000020",
        version: "APSC-DV-000020",
        status: "Applicable - Configurable",
        satisfied_by: [],
        satisfies: [{ id: 1, rule_id: "000010", srg_id: "SRG-OS-000010" }],
        disa_rule_descriptions_attributes: [{ vuln_discussion: "" }],
        checks_attributes: [{ content: "" }],
        rule_descriptions_attributes: [],
      };

      const wrapper = createWrapper([rule1, rule2]);

      // Simulate local status change (user changes status but hasn't saved yet)
      wrapper.vm.reactiveRules[0].status = "Not Applicable";

      const { removeSatisfaction } = await import("@/api/rulesApi");
      removeSatisfaction.mockResolvedValue({
        data: { toast: "Successfully removed satisfaction" },
      });

      // Act: Remove satisfaction
      await wrapper.vm.removeSatisfiedRule(1, 2);
      await wrapper.vm.$nextTick();

      // Assert: Local status change should be PRESERVED
      expect(wrapper.vm.reactiveRules[0].status).toBe("Not Applicable");

      // Also verify the satisfaction was removed
      expect(wrapper.vm.reactiveRules[0].satisfied_by.length).toBe(0);
      expect(wrapper.vm.reactiveRules[1].satisfies.length).toBe(0);
    });
  });
});
