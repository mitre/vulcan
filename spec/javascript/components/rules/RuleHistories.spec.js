import { describe, it, expect, afterEach, beforeEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleHistories from "@/components/rules/RuleHistories.vue";

vi.mock("@/composables/useHistoryGrouping", { spy: true });
import { useHistoryGrouping } from "@/composables/useHistoryGrouping";

/**
 * RuleHistories Component Tests
 *
 * REQUIREMENTS:
 * - Shows a "Revision History" heading with a badge counting GROUPED
 *   histories (bulk saves within the 5s grouping interval with the same
 *   author + comment collapse into one entry) via useHistoryGrouping.
 * - Renders the shared History timeline with the raw histories.
 * - Shows an empty-state message when there are no histories.
 */
describe("RuleHistories", () => {
  let wrapper;

  // First two entries: same author + comment, 1s apart → ONE group.
  // Third entry: different author/comment/time → its own group.
  const histories = [
    {
      id: 1,
      name: "Demo Admin",
      comment: "Updated title",
      action: "update",
      created_at: "2026-03-30T10:00:00.000Z",
      audited_changes: [],
    },
    {
      id: 2,
      name: "Demo Admin",
      comment: "Updated title",
      action: "update",
      created_at: "2026-03-30T10:00:01.000Z",
      audited_changes: [],
    },
    {
      id: 3,
      name: "Other User",
      comment: "Changed status",
      action: "update",
      created_at: "2026-03-30T11:00:00.000Z",
      audited_changes: [],
    },
  ];

  const createWrapper = (props = {}) => {
    return mount(RuleHistories, {
      localVue,
      propsData: {
        rule: { id: 1, rule_id: "000001", histories },
        statuses: ["Not Yet Determined"],
        component: { id: 41 },
        ...props,
      },
      stubs: { History: true },
    });
  };

  beforeEach(() => vi.clearAllMocks());

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("grouped history count", () => {
    it("badges the GROUPED count via useHistoryGrouping — bulk saves collapse", () => {
      wrapper = createWrapper();
      expect(useHistoryGrouping).toHaveBeenCalled();
      // 3 raw histories → 2 groups (ids 1+2 share author/comment within 5s)
      expect(wrapper.find(".badge").text()).toBe("2");
    });

    it("counts distinct comments as separate groups", () => {
      wrapper = createWrapper({
        rule: {
          id: 1,
          rule_id: "000001",
          histories: [histories[0], { ...histories[1], comment: "Different comment" }],
        },
      });
      expect(wrapper.find(".badge").text()).toBe("2");
    });
  });

  describe("empty state", () => {
    it("shows the empty message when there are no histories", () => {
      wrapper = createWrapper({ rule: { id: 1, rule_id: "000001", histories: [] } });
      expect(wrapper.text()).toContain("No revision history yet.");
    });
  });
});
