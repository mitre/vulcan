import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import HistoryGroupingMixin from "@/mixins/HistoryGroupingMixin.vue";

/**
 * HistoryGroupingMixin Tests
 *
 * REQUIREMENTS:
 *
 * 1. roundToNearestInterval(dateString):
 *    - Takes a date string, returns ISO string with seconds and milliseconds zeroed
 *    - Used to group edits that happen within the same minute
 *
 * 2. groupHistories(histories):
 *    - Groups history entries by composite key: name + rounded time + comment
 *    - Returns array of groups, each with { id, history (first entry), histories[] }
 *    - Same user editing within same minute with same comment -> single group
 *    - Different users -> separate groups
 *    - Different comments -> separate groups
 *    - Different minutes -> separate groups
 */

const HostComponent = {
  mixins: [HistoryGroupingMixin],
  template: "<div></div>",
};

function createWrapper() {
  return mount(HostComponent, { localVue });
}

describe("HistoryGroupingMixin", () => {
  // ==========================================
  // roundToNearestInterval
  // ==========================================
  describe("roundToNearestInterval", () => {
    it("rounds to nearest 5-second interval", () => {
      const wrapper = createWrapper();
      const result = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:47.123Z");
      const date = new Date(result);

      // 47.123s rounds to 45s (nearest 5s boundary)
      expect(date.getUTCSeconds()).toBe(45);
      expect(date.getUTCMilliseconds()).toBe(0);
    });

    it("preserves year, month, day, hour, and minute", () => {
      const wrapper = createWrapper();
      const result = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:42.000Z");
      const date = new Date(result);

      expect(date.getUTCFullYear()).toBe(2025);
      expect(date.getUTCMonth()).toBe(5); // June = 5 (0-indexed)
      expect(date.getUTCDate()).toBe(15);
      expect(date.getUTCHours()).toBe(10);
      expect(date.getUTCMinutes()).toBe(30);
    });

    it("returns a valid ISO string", () => {
      const wrapper = createWrapper();
      const result = wrapper.vm.roundToNearestInterval("2025-01-01T00:00:59.999Z");

      // Should be parseable and end with Z
      expect(new Date(result).toISOString()).toBe(result);
    });

    it("groups timestamps within same 5s window", () => {
      const wrapper = createWrapper();
      const a = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:01.000Z");
      const b = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:02.000Z");

      expect(a).toBe(b);
    });

    it("separates timestamps in different 5s windows", () => {
      const wrapper = createWrapper();
      const a = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:01.000Z");
      const b = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:08.000Z");

      expect(a).not.toBe(b);
    });
  });

  // ==========================================
  // groupHistories — SAME GROUP
  // ==========================================
  describe("groupHistories — entries in same group", () => {
    it("groups entries with same name, within 5s, and same comment", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:01Z", comment: "Updated title" },
        { name: "Alice", created_at: "2025-06-15T10:30:02Z", comment: "Updated title" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(1);
      expect(groups[0].histories).toHaveLength(2);
    });

    it("uses first entry as the group history reference", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:01Z", comment: "Edit" },
        { name: "Alice", created_at: "2025-06-15T10:30:02Z", comment: "Edit" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups[0].history).toBe(histories[0]);
    });

    it("constructs group id from name-roundedTime-comment", () => {
      const wrapper = createWrapper();
      const histories = [{ name: "Alice", created_at: "2025-06-15T10:30:01Z", comment: "Edit" }];

      const groups = wrapper.vm.groupHistories(histories);
      const roundedTime = wrapper.vm.roundToNearestInterval("2025-06-15T10:30:01Z");

      expect(groups[0].id).toBe(`Alice-${roundedTime}-Edit`);
    });
  });

  // ==========================================
  // groupHistories — SEPARATE GROUPS
  // ==========================================
  describe("groupHistories — entries in separate groups", () => {
    it("separates entries from different users", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:10Z", comment: "Edit" },
        { name: "Bob", created_at: "2025-06-15T10:30:10Z", comment: "Edit" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(2);
    });

    it("separates entries with different comments", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:10Z", comment: "Updated title" },
        { name: "Alice", created_at: "2025-06-15T10:30:10Z", comment: "Updated status" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(2);
    });

    it("separates entries from different time windows", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:01Z", comment: "Edit" },
        { name: "Alice", created_at: "2025-06-15T10:30:10Z", comment: "Edit" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(2);
    });
  });

  // ==========================================
  // groupHistories — EDGE CASES
  // ==========================================
  describe("groupHistories — edge cases", () => {
    it("returns empty array for empty input", () => {
      const wrapper = createWrapper();
      const groups = wrapper.vm.groupHistories([]);

      expect(groups).toEqual([]);
    });

    it("returns single group for single entry", () => {
      const wrapper = createWrapper();
      const histories = [{ name: "Alice", created_at: "2025-06-15T10:30:10Z", comment: "Edit" }];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(1);
      expect(groups[0].histories).toHaveLength(1);
    });

    it("handles multiple groups with different sizes", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:01.000Z", comment: "Edit" },
        { name: "Alice", created_at: "2025-06-15T10:30:01.500Z", comment: "Edit" },
        { name: "Alice", created_at: "2025-06-15T10:30:02.000Z", comment: "Edit" },
        { name: "Bob", created_at: "2025-06-15T10:30:01.000Z", comment: "Review" },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      expect(groups).toHaveLength(2);
      // Alice's group has 3, Bob's has 1
      const aliceGroup = groups.find((g) => g.history.name === "Alice");
      const bobGroup = groups.find((g) => g.history.name === "Bob");
      expect(aliceGroup.histories).toHaveLength(3);
      expect(bobGroup.histories).toHaveLength(1);
    });

    it("handles null comment in grouping key", () => {
      const wrapper = createWrapper();
      const histories = [
        { name: "Alice", created_at: "2025-06-15T10:30:01Z", comment: null },
        { name: "Alice", created_at: "2025-06-15T10:30:02Z", comment: null },
      ];

      const groups = wrapper.vm.groupHistories(histories);

      // Both have same name, same 5s window, same comment (null) — should group together
      expect(groups).toHaveLength(1);
      expect(groups[0].histories).toHaveLength(2);
    });
  });
});
