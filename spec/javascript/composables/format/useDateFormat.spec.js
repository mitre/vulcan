import { describe, it, expect } from "vitest";
import { useDateFormat } from "@/composables/format/useDateFormat";

describe("useDateFormat", () => {
  it("returns friendlyDateTime, friendlyDate, and relativeTime functions", () => {
    const fmt = useDateFormat();
    expect(typeof fmt.friendlyDateTime).toBe("function");
    expect(typeof fmt.friendlyDate).toBe("function");
    expect(typeof fmt.relativeTime).toBe("function");
  });

  describe("friendlyDateTime", () => {
    it("formats an ISO string to locale string", () => {
      const { friendlyDateTime } = useDateFormat();
      const result = friendlyDateTime("2026-05-01T10:30:00Z");
      expect(result).toMatch(/2026/);
      expect(result).not.toBe("");
    });

    it("returns empty string for null", () => {
      const { friendlyDateTime } = useDateFormat();
      expect(friendlyDateTime(null)).toBe("");
    });

    it("returns empty string for undefined", () => {
      const { friendlyDateTime } = useDateFormat();
      expect(friendlyDateTime(undefined)).toBe("");
    });
  });

  describe("friendlyDate", () => {
    it("formats an ISO string to date-only locale string", () => {
      const { friendlyDate } = useDateFormat();
      const result = friendlyDate("2026-05-01T10:30:00Z");
      expect(result).toMatch(/2026/);
      expect(result).not.toBe("");
    });

    it("returns empty string for null", () => {
      const { friendlyDate } = useDateFormat();
      expect(friendlyDate(null)).toBe("");
    });
  });

  describe("relativeTime", () => {
    it("returns 'm ago' for recent timestamps", () => {
      const { relativeTime } = useDateFormat();
      const fiveMinAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
      expect(relativeTime(fiveMinAgo)).toBe("5m ago");
    });

    it("returns 'h ago' for hour-old timestamps", () => {
      const { relativeTime } = useDateFormat();
      const twoHoursAgo = new Date(
        Date.now() - 2 * 60 * 60 * 1000,
      ).toISOString();
      expect(relativeTime(twoHoursAgo)).toBe("2h ago");
    });

    it("returns 'd ago' for day-old timestamps", () => {
      const { relativeTime } = useDateFormat();
      const threeDaysAgo = new Date(
        Date.now() - 3 * 24 * 60 * 60 * 1000,
      ).toISOString();
      expect(relativeTime(threeDaysAgo)).toBe("3d ago");
    });

    it("returns empty string for null", () => {
      const { relativeTime } = useDateFormat();
      expect(relativeTime(null)).toBe("");
    });
  });
});
