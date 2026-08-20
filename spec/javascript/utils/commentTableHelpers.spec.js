import { describe, it, expect } from "vitest";
import { ruleHref, rowTriageClass } from "@/utils/commentTableHelpers";

describe("commentTableHelpers", () => {
  describe("ruleHref", () => {
    it("builds a deep link from row.component_id and row.rule_displayed_name", () => {
      const row = { component_id: 8, rule_displayed_name: "CNTR-01-000003" };
      expect(ruleHref(row)).toBe("/components/8/CNTR-01-000003");
    });

    it("URL-encodes special characters in the rule name", () => {
      const row = { component_id: 8, rule_displayed_name: "FOO BAR/BAZ#1" };
      expect(ruleHref(row)).toBe(`/components/8/${encodeURIComponent("FOO BAR/BAZ#1")}`);
    });

    it("uses fallbackComponentId when row.component_id is null", () => {
      const row = { component_id: null, rule_displayed_name: "CNTR-01-000001" };
      expect(ruleHref(row, 42)).toBe("/components/42/CNTR-01-000001");
    });

    it("prefers row.component_id over fallback", () => {
      const row = { component_id: 8, rule_displayed_name: "CNTR-01-000001" };
      expect(ruleHref(row, 99)).toBe("/components/8/CNTR-01-000001");
    });
  });

  describe("rowTriageClass", () => {
    it("returns the triage background class for a valid status", () => {
      const result = rowTriageClass({ triage_status: "pending" });
      expect(typeof result).toBe("string");
    });

    it("handles null item gracefully", () => {
      expect(rowTriageClass(null)).toBeFalsy();
    });

    it("handles item with no triage_status gracefully", () => {
      expect(rowTriageClass({})).toBeFalsy();
    });
  });
});
