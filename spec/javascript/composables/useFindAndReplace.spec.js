import { describe, it, expect } from "vitest";
import { useFindAndReplace, FIND_AND_REPLACE_FIELDS } from "@/composables/useFindAndReplace";

// REQUIREMENT: useFindAndReplace must replicate FindAndReplaceMixin's engine —
// grouping matches per rule, splitting values into highlighted segments, and
// rebuilding field text on replace — with the same signatures so Phase 2
// migration is drop-in.
//
// Two INTENTIONAL fixes over the mixin (Gate 11, documented):
//   1. Match scanning is non-overlapping (advance by find length, matching
//      String.replaceAll semantics). The mixin advanced by 1 and produced
//      corrupted text for overlapping matches (find "aa" in "aaa").
//   2. Empty find text returns no matches instead of infinite-looping in
//      indexOf("").
describe("useFindAndReplace", () => {
  const { groupFindResults, getSegments, replaceTextInRule } = useFindAndReplace();

  describe("FIND_AND_REPLACE_FIELDS", () => {
    it("maps all 8 searchable fields to their rule paths", () => {
      expect(Object.keys(FIND_AND_REPLACE_FIELDS)).toEqual([
        "Status Justification",
        "Title",
        "Artifact Description",
        "Vulnerability Discussion",
        "Mitigations",
        "Check",
        "Fix",
        "Vendor Comments",
      ]);
      expect(FIND_AND_REPLACE_FIELDS.Fix).toEqual(["fixtext"]);
      expect(FIND_AND_REPLACE_FIELDS.Check).toEqual(["checks_attributes", 0, "content"]);
    });
  });

  describe("getSegments", () => {
    it("splits a value into alternating plain and highlighted segments", () => {
      const segments = getSegments("set the audit flag", "audit", true);
      expect(segments).toEqual([
        { text: "set the ", highlighted: false },
        { text: "audit", highlighted: true },
        { text: " flag", highlighted: false },
      ]);
    });

    it("finds multiple matches", () => {
      const segments = getSegments("foo bar foo", "foo", true);
      expect(segments).toEqual([
        { text: "", highlighted: false },
        { text: "foo", highlighted: true },
        { text: " bar ", highlighted: false },
        { text: "foo", highlighted: true },
        { text: "", highlighted: false },
      ]);
    });

    it("preserves original casing in segments when matching case-insensitively", () => {
      const segments = getSegments("The Audit log", "audit", false);
      expect(segments).toEqual([
        { text: "The ", highlighted: false },
        { text: "Audit", highlighted: true },
        { text: " log", highlighted: false },
      ]);
    });

    it("segments always reassemble to the exact original value", () => {
      const value = "aaa bbb aaa bbb aaa";
      const segments = getSegments(value, "aaa", true);
      expect(segments.map((s) => s.text).join("")).toBe(value);
    });

    it("scans non-overlapping matches (fix: mixin advanced by 1 and corrupted text)", () => {
      const segments = getSegments("aaa", "aa", true);
      // Non-overlapping: ONE match at index 0, remainder "a".
      expect(segments).toEqual([
        { text: "", highlighted: false },
        { text: "aa", highlighted: true },
        { text: "a", highlighted: false },
      ]);
      expect(segments.map((s) => s.text).join("")).toBe("aaa");
    });

    it("returns the whole value un-highlighted for empty find text (fix: mixin infinite loop)", () => {
      expect(getSegments("some text", "", true)).toEqual([
        { text: "some text", highlighted: false },
      ]);
    });
  });

  describe("groupFindResults", () => {
    const rules = [
      {
        id: 1,
        rule_id: "000001",
        title: "Configure audit logging",
        fixtext: "Enable the audit daemon",
        disa_rule_descriptions_attributes: [{ vuln_discussion: "No audit trail exists" }],
        checks_attributes: [{ content: "Verify auditd is running" }],
      },
      {
        id: 2,
        rule_id: "000002",
        title: "Disable telnet",
        fixtext: null,
        disa_rule_descriptions_attributes: [{ vuln_discussion: "Cleartext protocol" }],
        checks_attributes: [{ content: "Check telnet is absent" }],
      },
    ];

    it("groups matches by rule id with rule_id and per-field results", () => {
      const results = groupFindResults(rules, "audit", false, ["Title", "Fix"]);

      expect(Object.keys(results)).toEqual(["1"]);
      expect(results[1].rule_id).toBe("000001");
      expect(results[1].results).toHaveLength(2);
      expect(results[1].results[0].field).toBe("Title");
      expect(results[1].results[0].value).toBe("Configure audit logging");
      expect(results[1].results[1].field).toBe("Fix");
      expect(results[1].results[1].value).toBe("Enable the audit daemon");
    });

    it("includes highlight segments on each result", () => {
      const results = groupFindResults(rules, "audit", false, ["Title"]);
      expect(results[1].results[0].segments).toEqual([
        { text: "Configure ", highlighted: false },
        { text: "audit", highlighted: true },
        { text: " logging", highlighted: false },
      ]);
    });

    it("searches nested field paths (Vulnerability Discussion)", () => {
      const results = groupFindResults(rules, "cleartext", false, ["Vulnerability Discussion"]);
      expect(Object.keys(results)).toEqual(["2"]);
      expect(results[2].results[0].value).toBe("Cleartext protocol");
    });

    it("only searches the requested fields", () => {
      const results = groupFindResults(rules, "audit", false, ["Vendor Comments"]);
      expect(results).toEqual({});
    });

    it("respects matchCase: true", () => {
      expect(groupFindResults(rules, "AUDIT", true, ["Title"])).toEqual({});
      expect(Object.keys(groupFindResults(rules, "AUDIT", false, ["Title"]))).toEqual(["1"]);
    });

    it("skips null and missing field values without crashing", () => {
      const results = groupFindResults(rules, "telnet", false, ["Title", "Fix"]);
      // Rule 2 matches on Title; its null fixtext is skipped silently.
      expect(Object.keys(results)).toEqual(["2"]);
      expect(results[2].results).toHaveLength(1);
    });

    it("returns no matches for empty find text (fix: mixin matched everything)", () => {
      expect(groupFindResults(rules, "", false, ["Title", "Fix"])).toEqual({});
    });
  });

  describe("replaceTextInRule", () => {
    it("rebuilds a flat field replacing highlighted segments", () => {
      const rule = { fixtext: "Enable the audit daemon" };
      const segments = getSegments(rule.fixtext, "audit", true);

      replaceTextInRule(rule, "Fix", segments, "syslog");

      expect(rule.fixtext).toBe("Enable the syslog daemon");
    });

    it("rebuilds a nested field via its path (Check)", () => {
      const rule = { checks_attributes: [{ content: "Verify auditd is running" }] };
      const segments = getSegments(rule.checks_attributes[0].content, "auditd", true);

      replaceTextInRule(rule, "Check", segments, "rsyslog");

      expect(rule.checks_attributes[0].content).toBe("Verify rsyslog is running");
    });

    it("replaces every highlighted occurrence", () => {
      const rule = { title: "audit the audit log" };
      const segments = getSegments(rule.title, "audit", true);

      replaceTextInRule(rule, "Title", segments, "review");

      expect(rule.title).toBe("review the review log");
    });
  });
});
