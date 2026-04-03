import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleCommandBar from "@/components/rules/RuleCommandBar.vue";

/**
 * RuleCommandBar Component Tests
 *
 * REQUIREMENTS:
 * RuleCommandBar displays rule-level context information:
 * - Context group: Rule ID, version, status icons, last editor
 *
 * NOTE: Panel buttons (Related, Satisfies, History, Reviews) and actions
 * are now in RuleActionsToolbar, grouped with other rule-level actions.
 */
describe("RuleCommandBar", () => {
  let wrapper;

  const mockRule = {
    id: 1,
    rule_id: "00001",
    version: "SV-12345r1",
    component_id: 41,
    status: "Not Yet Determined",
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    reviews: [{ id: 1 }, { id: 2 }],
    histories: [{ name: "John Doe", created_at: "2024-01-15" }],
    updated_at: "2024-01-15T10:00:00Z",
  };

  const createWrapper = (props = {}) => {
    return shallowMount(RuleCommandBar, {
      localVue,
      propsData: {
        rule: mockRule,
        componentPrefix: "TEST",
        ...props,
      },
      stubs: {
        BIcon: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
    }
  });

  describe("rendering", () => {
    it("renders the command bar container", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".command-bar").exists()).toBe(true);
    });

    it("displays the rule ID with component prefix", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("TEST-00001");
    });

    it("displays the rule version", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("SV-12345r1");
    });

    it("shows lock icon when rule is locked", () => {
      wrapper = createWrapper({
        rule: { ...mockRule, locked: true },
      });
      const lockIcon = wrapper.find('[icon="lock"]');
      expect(lockIcon.exists()).toBe(true);
    });

    it("shows review icon when rule is under review", () => {
      wrapper = createWrapper({
        rule: { ...mockRule, review_requestor_id: 123 },
      });
      const reviewIcon = wrapper.find('[icon="file-earmark-search"]');
      expect(reviewIcon.exists()).toBe(true);
    });

    it("shows warning icon when changes are requested", () => {
      wrapper = createWrapper({
        rule: { ...mockRule, changes_requested: true },
      });
      const warningIcon = wrapper.find('[icon="exclamation-triangle"]');
      expect(warningIcon.exists()).toBe(true);
    });
  });

  describe("last editor display", () => {
    it("shows last editor name when histories exist", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("John Doe");
    });

    it("does not show last editor when no histories", () => {
      wrapper = createWrapper({
        rule: { ...mockRule, histories: [] },
      });
      expect(wrapper.text()).not.toContain("Updated");
    });
  });

  // Panel buttons moved to RuleActionsToolbar.spec.js
  // (Related, Satisfies, History, Reviews are now with rule actions)

  describe("computed properties", () => {
    it("computes lastEditor from histories", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.lastEditor).toBe("John Doe");
    });

    it("computes lastEditor as null when no histories", () => {
      wrapper = createWrapper({
        rule: { ...mockRule, histories: [] },
      });
      expect(wrapper.vm.lastEditor).toBeNull();
    });
  });
});
