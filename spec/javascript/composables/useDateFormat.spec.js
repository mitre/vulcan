import { describe, it, expect } from "vitest";
import moment from "moment";
import { useDateFormat } from "../../../app/javascript/composables/useDateFormat";

describe("useDateFormat", () => {
  const { friendlyDateTime } = useDateFormat();

  describe("friendlyDateTime", () => {
    it("formats an ISO datetime string to moment lll format (local timezone)", () => {
      const input = "2026-06-07T10:30:00Z";
      const expected = moment(input).format("lll");
      expect(friendlyDateTime(input)).toBe(expected);
    });

    it("handles datetime with UTC suffix", () => {
      const input = "2026-06-07 10:30:00 UTC";
      const normalized = input.replace(/ UTC$/, "Z").replace(" ", "T");
      const expected = moment(normalized).format("lll");
      expect(friendlyDateTime(input)).toBe(expected);
    });

    it("handles datetime with space instead of T separator", () => {
      const input = "2026-06-07 10:30:00Z";
      const normalized = input.replace(" ", "T");
      const expected = moment(normalized).format("lll");
      expect(friendlyDateTime(input)).toBe(expected);
    });

    it("returns empty string for null", () => {
      expect(friendlyDateTime(null)).toBe("");
    });

    it("returns empty string for undefined", () => {
      expect(friendlyDateTime(undefined)).toBe("");
    });

    it("returns empty string for empty string", () => {
      expect(friendlyDateTime("")).toBe("");
    });

    it("produces output matching the original DateFormatMixin behavior", () => {
      const input = "2026-01-15T14:00:00.000Z";
      const expected = moment(input).format("lll");
      expect(friendlyDateTime(input)).toBe(expected);
    });

    it("produces a non-empty formatted string for valid input", () => {
      const result = friendlyDateTime("2026-03-15T09:00:00Z");
      expect(result).toMatch(/Mar 15, 2026/);
      expect(result.length).toBeGreaterThan(10);
    });
  });
});
