import { describe, it, expect } from "vitest";
import { useHistoryGrouping } from "../../../app/javascript/composables/useHistoryGrouping";

describe("useHistoryGrouping", () => {
  const { groupHistories, roundToNearestInterval } = useHistoryGrouping();

  describe("roundToNearestInterval", () => {
    it("rounds to nearest 5-second window", () => {
      const result = roundToNearestInterval("2026-06-07T10:00:02.500Z");
      expect(result).toBe("2026-06-07T10:00:05.000Z");
    });

    it("rounds down when below midpoint", () => {
      const result = roundToNearestInterval("2026-06-07T10:00:01.000Z");
      expect(result).toBe("2026-06-07T10:00:00.000Z");
    });
  });

  describe("groupHistories", () => {
    it("groups histories by name + rounded timestamp + comment", () => {
      const histories = [
        { name: "Admin", created_at: "2026-06-07T10:00:01Z", comment: null, action: "update" },
        { name: "Admin", created_at: "2026-06-07T10:00:02Z", comment: null, action: "update" },
      ];
      const groups = groupHistories(histories);
      expect(groups).toHaveLength(1);
      expect(groups[0].histories).toHaveLength(2);
    });

    it("separates histories with different names", () => {
      const histories = [
        { name: "Admin", created_at: "2026-06-07T10:00:01Z", comment: null, action: "update" },
        { name: "Viewer", created_at: "2026-06-07T10:00:01Z", comment: null, action: "update" },
      ];
      const groups = groupHistories(histories);
      expect(groups).toHaveLength(2);
    });

    it("separates histories with different timestamps beyond 5s", () => {
      const histories = [
        { name: "Admin", created_at: "2026-06-07T10:00:00Z", comment: null, action: "update" },
        { name: "Admin", created_at: "2026-06-07T10:00:30Z", comment: null, action: "update" },
      ];
      const groups = groupHistories(histories);
      expect(groups).toHaveLength(2);
    });

    it("sets the first history as the group header", () => {
      const histories = [
        { name: "Admin", created_at: "2026-06-07T10:00:01Z", comment: "test", action: "update" },
      ];
      const groups = groupHistories(histories);
      expect(groups[0].history).toBe(histories[0]);
    });

    it("returns empty array for empty input", () => {
      expect(groupHistories([])).toEqual([]);
    });
  });
});
