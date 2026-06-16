import { describe, it, expect, afterEach } from "vitest";
import { shallowMount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleRowIcons from "@/components/rules/RuleRowIcons.vue";

/**
 * RuleRowIcons requirements:
 *
 * Renders the status indicator icons for a single rule row in the navigator.
 * Icons shown conditionally based on rule properties:
 * 1. Comment badge (chat icon + tooltip) when ruleOpen > 0
 * 2. "Satisfies other" indicator when rule.satisfies.length > 0
 * 3. "Satisfied by other" indicator when rule.satisfied_by.length > 0
 * 4. Review requested icon when rule.review_requestor_id is set
 * 5. Lock icon when rule.locked is true
 * 6. Changes requested icon when rule.changes_requested is true
 *
 * This was extracted from RuleNavigator to DRY the identical 3-place pattern
 * (open rules, all rules, nested children all rendered the same icons).
 */
describe("RuleRowIcons", () => {
  let wrapper;

  const createRule = (overrides = {}) => ({
    id: 1,
    satisfies: [],
    satisfied_by: [],
    locked: false,
    review_requestor_id: null,
    changes_requested: false,
    ...overrides,
  });

  const createWrapper = (props = {}) => {
    return shallowMount(RuleRowIcons, {
      localVue,
      propsData: {
        rule: createRule(props.rule || {}),
        ruleOpen: props.ruleOpen || 0,
      },
      stubs: {
        BIcon: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("comment badge", () => {
    it("renders comment badge when ruleOpen > 0", () => {
      wrapper = createWrapper({ ruleOpen: 3, rule: { id: 5 } });
      const badge = wrapper.find('[data-test="rule-open-comment-5"]');
      expect(badge.exists()).toBe(true);
    });

    it("does not render comment badge when ruleOpen is 0", () => {
      wrapper = createWrapper({ ruleOpen: 0, rule: { id: 5 } });
      const badge = wrapper.find('[data-test="rule-open-comment-5"]');
      expect(badge.exists()).toBe(false);
    });

    it("tooltip contains the open comment count", () => {
      wrapper = createWrapper({ ruleOpen: 7, rule: { id: 1 } });
      const badge = wrapper.find('[data-test="rule-open-comment-1"]');
      expect(badge.attributes("title")).toContain("7");
    });
  });

  describe("status icons", () => {
    it("renders review-requested icon when review_requestor_id is set", () => {
      wrapper = createWrapper({ rule: { review_requestor_id: 42 } });
      const icon = wrapper.find('[data-test="icon-review-requested"]');
      expect(icon.exists()).toBe(true);
    });

    it("does not render review-requested icon when review_requestor_id is null", () => {
      wrapper = createWrapper({ rule: { review_requestor_id: null } });
      const icon = wrapper.find('[data-test="icon-review-requested"]');
      expect(icon.exists()).toBe(false);
    });

    it("renders lock icon when locked is true", () => {
      wrapper = createWrapper({ rule: { locked: true } });
      const icon = wrapper.find('[data-test="icon-locked"]');
      expect(icon.exists()).toBe(true);
    });

    it("does not render lock icon when locked is false", () => {
      wrapper = createWrapper({ rule: { locked: false } });
      const icon = wrapper.find('[data-test="icon-locked"]');
      expect(icon.exists()).toBe(false);
    });

    it("renders changes-requested icon when changes_requested is true", () => {
      wrapper = createWrapper({ rule: { changes_requested: true } });
      const icon = wrapper.find('[data-test="icon-changes-requested"]');
      expect(icon.exists()).toBe(true);
    });

    it("does not render changes-requested icon when changes_requested is false", () => {
      wrapper = createWrapper({ rule: { changes_requested: false } });
      const icon = wrapper.find('[data-test="icon-changes-requested"]');
      expect(icon.exists()).toBe(false);
    });
  });
});
