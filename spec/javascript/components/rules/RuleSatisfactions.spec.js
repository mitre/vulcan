import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleSatisfactions from "@/components/rules/RuleSatisfactions.vue";

/**
 * RuleSatisfactions — Business Requirements
 *
 * 1. "Also Satisfies" section: visible when rule has NO satisfied_by relationships.
 * 2. "Satisfied By" section: visible when rule HAS satisfied_by relationships.
 * 3. SRG ID display: truncated ID shown as text, full ID in tooltip.
 * 4. Add button: only when status is "Applicable - Configurable", disabled when readOnly.
 * 5. Remove buttons: present for each satisfaction, disabled when readOnly.
 * 6. readOnly message: "Edit mode required to modify" when readOnly is true.
 * 7. Empty state: "No other controls satisfied by this one." when satisfies is empty.
 * 8. Badge counts: display count of satisfies / satisfied_by relationships.
 * 9. Click navigation: clicking SRG ID emits ruleSelected with rule ID.
 * 10. Row highlighting: selected rule gets selectedRuleRow class.
 */

// --- Test data ---

const makeSatisfaction = (id, srgId) => ({
  id,
  rule_id: String(id).padStart(6, "0"),
  srg_id: srgId,
});

const sat1 = makeSatisfaction(10, "SRG-OS-000010-GPOS-00010");
const sat2 = makeSatisfaction(20, "SRG-OS-000020-GPOS-00020");

const baseRule = {
  id: 1,
  rule_id: "001",
  status: "Applicable - Configurable",
  satisfies: [],
  satisfied_by: [],
};

const defaultProps = {
  component: { id: 100 },
  rule: { ...baseRule },
  projectPrefix: "TEST",
  readOnly: false,
};

// --- Helpers ---

const createWrapper = (propsOverrides = {}) => {
  const wrapper = mount(RuleSatisfactions, {
    localVue,
    propsData: {
      ...defaultProps,
      ...propsOverrides,
    },
  });

  // Spy on $root.$emit after mount (Vue 2 sets $root internally, mocks won't override it)
  const rootEmit = vi.spyOn(wrapper.vm.$root, "$emit");

  return { wrapper, rootEmit };
};

describe("RuleSatisfactions", () => {
  let wrapper;
  let rootEmit;

  afterEach(() => {
    if (wrapper) {
      wrapper.destroy();
      wrapper = null;
    }
  });

  // ---------------------------------------------------------------
  // Requirement 1: "Also Satisfies" section visibility
  // ---------------------------------------------------------------
  describe("Also Satisfies section visibility", () => {
    it("shows Also Satisfies section when rule has no satisfied_by relationships", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [], satisfies: [] },
      }));
      expect(wrapper.text()).toContain("Also Satisfies");
    });

    it("hides Also Satisfies section when rule IS satisfied by other rules", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1], satisfies: [] },
      }));
      expect(wrapper.text()).not.toContain("Also Satisfies");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 2: "Satisfied By" section visibility
  // ---------------------------------------------------------------
  describe("Satisfied By section visibility", () => {
    it("shows Satisfied By section when rule has satisfied_by relationships", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1] },
      }));
      expect(wrapper.text()).toContain("Satisfied By");
    });

    it("hides Satisfied By section when satisfied_by is empty", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [] },
      }));
      expect(wrapper.text()).not.toContain("Satisfied By");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 3: SRG ID display (truncated text, full tooltip)
  // ---------------------------------------------------------------
  describe("SRG ID display", () => {
    it("displays truncated SRG ID for satisfies relationships", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
      }));
      // truncateId("SRG-OS-000010-GPOS-00010") => "SRG-OS-000010"
      const clickableSpans = wrapper.findAll(".clickable");
      expect(clickableSpans.length).toBe(1);
      expect(clickableSpans.at(0).text()).toBe("SRG-OS-000010");
    });

    it("sets full SRG ID as tooltip title on satisfies entries", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
      }));
      const span = wrapper.find(".clickable");
      expect(span.attributes("title")).toBe("SRG-OS-000010-GPOS-00010");
    });

    it("displays truncated SRG ID for satisfied_by relationships", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat2] },
      }));
      const span = wrapper.find(".clickable");
      expect(span.text()).toBe("SRG-OS-000020");
    });

    it("sets full SRG ID as tooltip title on satisfied_by entries", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat2] },
      }));
      const span = wrapper.find(".clickable");
      expect(span.attributes("title")).toBe("SRG-OS-000020-GPOS-00020");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 4: Add button (status-gated, readOnly-disabled)
  // ---------------------------------------------------------------
  describe("Add button", () => {
    it('shows Add button when rule status is "Applicable - Configurable"', () => {
      ({ wrapper } = createWrapper({
        rule: {
          ...baseRule,
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
        },
      }));
      const addBtn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Add"));
      expect(addBtn).toBeTruthy();
    });

    it("hides Add button when rule status is not Applicable - Configurable", () => {
      ({ wrapper } = createWrapper({
        rule: {
          ...baseRule,
          status: "Not Applicable",
          satisfies: [],
          satisfied_by: [],
        },
      }));
      const addBtn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Add"));
      expect(addBtn).toBeUndefined();
    });

    it("disables Add button when readOnly is true", () => {
      ({ wrapper } = createWrapper({
        rule: {
          ...baseRule,
          status: "Applicable - Configurable",
          satisfies: [],
          satisfied_by: [],
        },
        readOnly: true,
      }));
      const addBtn = wrapper.findAll("button").wrappers.find((b) => b.text().includes("Add"));
      expect(addBtn).toBeTruthy();
      expect(addBtn.attributes("disabled")).toBeDefined();
    });
  });

  // ---------------------------------------------------------------
  // Requirement 5: Remove buttons (present, readOnly-disabled)
  // ---------------------------------------------------------------
  describe("Remove buttons", () => {
    it("shows a Remove button for each satisfies relationship", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1, sat2], satisfied_by: [] },
      }));
      const removeBtns = wrapper.findAll("button").wrappers.filter((b) => b.text() === "Remove");
      expect(removeBtns.length).toBe(2);
    });

    it("shows a Remove button for each satisfied_by relationship", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1] },
      }));
      const removeBtns = wrapper.findAll("button").wrappers.filter((b) => b.text() === "Remove");
      expect(removeBtns.length).toBe(1);
    });

    it("disables Remove buttons when readOnly is true (satisfies section)", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
        readOnly: true,
      }));
      const removeBtns = wrapper.findAll("button").wrappers.filter((b) => b.text() === "Remove");
      removeBtns.forEach((btn) => {
        expect(btn.attributes("disabled")).toBeDefined();
      });
    });

    it("disables Remove buttons when readOnly is true (satisfied_by section)", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1] },
        readOnly: true,
      }));
      const removeBtns = wrapper.findAll("button").wrappers.filter((b) => b.text() === "Remove");
      removeBtns.forEach((btn) => {
        expect(btn.attributes("disabled")).toBeDefined();
      });
    });
  });

  // ---------------------------------------------------------------
  // Requirement 6: readOnly message
  // ---------------------------------------------------------------
  describe("readOnly message", () => {
    it('shows "Edit mode required to modify" in Also Satisfies section when readOnly', () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [], satisfied_by: [] },
        readOnly: true,
      }));
      expect(wrapper.text()).toContain("Edit mode required to modify");
    });

    it('shows "Edit mode required to modify" in Satisfied By section when readOnly', () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1] },
        readOnly: true,
      }));
      expect(wrapper.text()).toContain("Edit mode required to modify");
    });

    it("does not show readOnly message when readOnly is false", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [], satisfied_by: [] },
        readOnly: false,
      }));
      expect(wrapper.text()).not.toContain("Edit mode required to modify");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 7: Empty state message
  // ---------------------------------------------------------------
  describe("empty state", () => {
    it('shows "No other controls satisfied by this one." when satisfies is empty', () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [], satisfied_by: [] },
      }));
      expect(wrapper.text()).toContain("No other controls satisfied by this one.");
    });

    it("does not show empty state message when satisfies has entries", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
      }));
      expect(wrapper.text()).not.toContain("No other controls satisfied by this one.");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 8: Badge counts
  // ---------------------------------------------------------------
  describe("badge counts", () => {
    it("shows badge with satisfies count in Also Satisfies section", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1, sat2], satisfied_by: [] },
      }));
      const badges = wrapper.findAll(".badge");
      expect(badges.length).toBe(1);
      expect(badges.at(0).text()).toBe("2");
    });

    it("shows badge with satisfied_by count in Satisfied By section", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat1, sat2] },
      }));
      const badges = wrapper.findAll(".badge");
      expect(badges.length).toBe(1);
      expect(badges.at(0).text()).toBe("2");
    });

    it("shows badge with 0 when satisfies is empty", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [], satisfied_by: [] },
      }));
      const badges = wrapper.findAll(".badge");
      expect(badges.length).toBe(1);
      expect(badges.at(0).text()).toBe("0");
    });
  });

  // ---------------------------------------------------------------
  // Requirement 9: Click navigation
  // ---------------------------------------------------------------
  describe("click navigation", () => {
    it("emits ruleSelected with rule ID when clicking a satisfies entry", async () => {
      ({ wrapper, rootEmit } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
      }));

      await wrapper.find(".clickable").trigger("click");

      expect(wrapper.emitted("ruleSelected")).toBeTruthy();
      expect(wrapper.emitted("ruleSelected")[0]).toEqual([sat1.id]);
    });

    it("emits ruleSelected with rule ID when clicking a satisfied_by entry", async () => {
      ({ wrapper, rootEmit } = createWrapper({
        rule: { ...baseRule, satisfied_by: [sat2] },
      }));

      await wrapper.find(".clickable").trigger("click");

      expect(wrapper.emitted("ruleSelected")).toBeTruthy();
      expect(wrapper.emitted("ruleSelected")[0]).toEqual([sat2.id]);
    });

    it("emits refresh:rule via $root when satisfaction has no histories", async () => {
      ({ wrapper, rootEmit } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
      }));

      await wrapper.find(".clickable").trigger("click");

      expect(rootEmit).toHaveBeenCalledWith("refresh:rule", sat1.id);
    });

    it("does not emit refresh:rule when satisfaction has histories", async () => {
      const satWithHistories = { ...sat1, histories: [{ id: 1 }] };
      ({ wrapper, rootEmit } = createWrapper({
        rule: { ...baseRule, satisfies: [satWithHistories], satisfied_by: [] },
      }));

      await wrapper.find(".clickable").trigger("click");

      expect(rootEmit).not.toHaveBeenCalledWith("refresh:rule", expect.anything());
      // ruleSelected should still emit
      expect(wrapper.emitted("ruleSelected")).toBeTruthy();
    });
  });

  // ---------------------------------------------------------------
  // Requirement 10: Row highlighting
  // ---------------------------------------------------------------
  describe("row highlighting", () => {
    it("applies selectedRuleRow class when selectedRuleId matches", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
        selectedRuleId: sat1.id,
      }));
      const row = wrapper.find(".ruleRow");
      expect(row.classes()).toContain("selectedRuleRow");
    });

    it("does not apply selectedRuleRow class when selectedRuleId does not match", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [] },
        selectedRuleId: 999,
      }));
      const row = wrapper.find(".ruleRow");
      expect(row.classes()).not.toContain("selectedRuleRow");
    });

    it("applies ruleRow class to all satisfaction rows", () => {
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1, sat2], satisfied_by: [] },
      }));
      const rows = wrapper.findAll(".ruleRow");
      expect(rows.length).toBe(2);
    });
  });

  // ---------------------------------------------------------------
  // Mutual exclusivity: Only one section renders at a time
  // ---------------------------------------------------------------
  describe("section mutual exclusivity", () => {
    it("never shows both sections simultaneously", () => {
      // When satisfied_by is populated, Also Satisfies is hidden
      ({ wrapper } = createWrapper({
        rule: { ...baseRule, satisfies: [sat1], satisfied_by: [sat2] },
      }));
      expect(wrapper.text()).toContain("Satisfied By");
      expect(wrapper.text()).not.toContain("Also Satisfies");
    });
  });

  // ---------------------------------------------------------------
  // Task 23 — comment count badges on related rules
  // ---------------------------------------------------------------
  describe("PR #717 comment count badges", () => {
    it("renders a pending-count badge on each satisfies row that has comments", () => {
      const ruleWithCounts = {
        ...baseRule,
        satisfies: [
          { ...sat1, pending_comment_count: 3, total_comment_count: 5 },
          { ...sat2, pending_comment_count: 0, total_comment_count: 0 },
        ],
      };
      ({ wrapper } = createWrapper({ rule: ruleWithCounts }));
      // The row with comments shows the pending count badge.
      expect(wrapper.text()).toMatch(/3 pending/i);
      // The data-test selector is stable across DOM refactors.
      expect(wrapper.find(`[data-test="related-rule-comment-count-${sat1.id}"]`).exists()).toBe(
        true,
      );
      // The row without comments does NOT show a badge.
      expect(wrapper.find(`[data-test="related-rule-comment-count-${sat2.id}"]`).exists()).toBe(
        false,
      );
    });

    it("renders a pending-count badge on each satisfied_by row that has comments", () => {
      const ruleWithCounts = {
        ...baseRule,
        satisfies: [],
        satisfied_by: [{ ...sat1, pending_comment_count: 2, total_comment_count: 2 }],
      };
      ({ wrapper } = createWrapper({ rule: ruleWithCounts, readOnly: true }));
      expect(wrapper.text()).toMatch(/2 pending/i);
      expect(wrapper.find(`[data-test="related-rule-comment-count-${sat1.id}"]`).exists()).toBe(
        true,
      );
    });

    it("does not render the badge when pending_comment_count is missing or zero", () => {
      const ruleNoCounts = {
        ...baseRule,
        satisfies: [{ ...sat1 }, { ...sat2, pending_comment_count: 0 }],
      };
      ({ wrapper } = createWrapper({ rule: ruleNoCounts }));
      expect(wrapper.text()).not.toMatch(/pending/i);
    });
  });
});
