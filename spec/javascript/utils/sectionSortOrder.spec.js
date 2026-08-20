import { describe, it, expect } from "vitest";
import { sectionIndex, compareBySectionOrder } from "@/utils/sectionSortOrder";
import { FIELD_DISPLAY_ORDER } from "@/composables/ruleFieldConfig";

describe("FIELD_DISPLAY_ORDER", () => {
  it("is a frozen array exported from ruleFieldConfig", () => {
    expect(Array.isArray(FIELD_DISPLAY_ORDER)).toBe(true);
    expect(Object.isFrozen(FIELD_DISPLAY_ORDER)).toBe(true);
  });

  it("title comes before vuln_discussion", () => {
    expect(FIELD_DISPLAY_ORDER.indexOf("title")).toBeLessThan(
      FIELD_DISPLAY_ORDER.indexOf("vuln_discussion"),
    );
  });

  it("vuln_discussion comes before check_content", () => {
    expect(FIELD_DISPLAY_ORDER.indexOf("vuln_discussion")).toBeLessThan(
      FIELD_DISPLAY_ORDER.indexOf("check_content"),
    );
  });

  it("check_content comes before fixtext", () => {
    expect(FIELD_DISPLAY_ORDER.indexOf("check_content")).toBeLessThan(
      FIELD_DISPLAY_ORDER.indexOf("fixtext"),
    );
  });

  it("fixtext comes before status_justification", () => {
    expect(FIELD_DISPLAY_ORDER.indexOf("fixtext")).toBeLessThan(
      FIELD_DISPLAY_ORDER.indexOf("status_justification"),
    );
  });

  it("status_justification comes before vendor_comments", () => {
    expect(FIELD_DISPLAY_ORDER.indexOf("status_justification")).toBeLessThan(
      FIELD_DISPLAY_ORDER.indexOf("vendor_comments"),
    );
  });

  it("advanced XCCDF fields come after vendor_comments", () => {
    const vendorIdx = FIELD_DISPLAY_ORDER.indexOf("vendor_comments");
    expect(FIELD_DISPLAY_ORDER.indexOf("version")).toBeGreaterThan(vendorIdx);
    expect(FIELD_DISPLAY_ORDER.indexOf("fix_id")).toBeGreaterThan(vendorIdx);
    expect(FIELD_DISPLAY_ORDER.indexOf("rule_weight")).toBeGreaterThan(vendorIdx);
  });
});

describe("sectionIndex", () => {
  it("returns -1 for null section (overall comments first)", () => {
    expect(sectionIndex(null)).toBe(-1);
  });

  it("returns -1 for undefined section", () => {
    expect(sectionIndex(undefined)).toBe(-1);
  });

  it("returns the FIELD_DISPLAY_ORDER position for a known field", () => {
    const expected = FIELD_DISPLAY_ORDER.indexOf("check_content");
    expect(sectionIndex("check_content")).toBe(expected);
  });

  it("normalizes 'content' to 'check_content'", () => {
    expect(sectionIndex("content")).toBe(sectionIndex("check_content"));
  });

  it("returns 998 for an unknown section", () => {
    expect(sectionIndex("some_unknown_field")).toBe(998);
  });

  it("title position is less than fixtext position", () => {
    expect(sectionIndex("title")).toBeLessThan(sectionIndex("fixtext"));
  });
});

describe("compareBySectionOrder", () => {
  const makeComment = (id, section) => ({ id, section });

  it("sorts null-section comments before section-specific comments", () => {
    const a = makeComment(100, null);
    const b = makeComment(1, "fixtext");
    expect(compareBySectionOrder(a, b)).toBeLessThan(0);
  });

  it("sorts by FIELD_DISPLAY_ORDER position when sections differ", () => {
    const a = makeComment(100, "fixtext");
    const b = makeComment(1, "title");
    expect(compareBySectionOrder(a, b)).toBeGreaterThan(0);
  });

  it("sorts by ID when sections are the same", () => {
    const a = makeComment(5, "check_content");
    const b = makeComment(3, "check_content");
    expect(compareBySectionOrder(a, b)).toBeGreaterThan(0);
  });

  it("sorts unknown sections after known sections", () => {
    const a = makeComment(1, "some_unknown");
    const b = makeComment(2, "fixtext");
    expect(compareBySectionOrder(a, b)).toBeGreaterThan(0);
  });

  it("sorts a realistic comment list in field order", () => {
    const comments = [
      makeComment(42, "check_content"),
      makeComment(43, "fixtext"),
      makeComment(78, null),
      makeComment(168, "vuln_discussion"),
      makeComment(171, "title"),
    ];
    const sorted = [...comments].sort(compareBySectionOrder);
    expect(sorted.map((c) => c.id)).toEqual([78, 171, 168, 42, 43]);
  });
});
