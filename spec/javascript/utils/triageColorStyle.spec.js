import { describe, it, expect } from "vitest";
import { triageBgClass } from "@/utils/triageBgClass";

/**
 * triageBgClass tests
 *
 * REQUIREMENTS:
 * 1. Returns a data-attribute CSS class for known triage statuses
 * 2. Returns empty string for null, undefined, or "pending" (no tint)
 * 3. Class format: "triage-bg--{status}" matching [data-triage] selectors
 */
describe("triageBgClass", () => {
  it('returns "triage-bg--concur" for concur status', () => {
    expect(triageBgClass("concur")).toBe("triage-bg--concur");
  });

  it('returns "triage-bg--non_concur" for non_concur status', () => {
    expect(triageBgClass("non_concur")).toBe("triage-bg--non_concur");
  });

  it('returns "triage-bg--addressed_by" for addressed_by status', () => {
    expect(triageBgClass("addressed_by")).toBe("triage-bg--addressed_by");
  });

  it('returns "triage-bg--duplicate" for duplicate status', () => {
    expect(triageBgClass("duplicate")).toBe("triage-bg--duplicate");
  });

  it('returns empty string for "pending" (no tint)', () => {
    expect(triageBgClass("pending")).toBe("");
  });

  it("returns empty string for null", () => {
    expect(triageBgClass(null)).toBe("");
  });

  it("returns empty string for undefined", () => {
    expect(triageBgClass(undefined)).toBe("");
  });

  it("returns empty string for empty string", () => {
    expect(triageBgClass("")).toBe("");
  });

  it("returns empty string for unknown status (validates against vocabulary)", () => {
    expect(triageBgClass("bogus_status")).toBe("");
    expect(triageBgClass("approved")).toBe("");
  });

  it("handles all statuses from triageVocabulary (except pending)", () => {
    const expected = [
      "concur", "concur_with_comment", "non_concur", "duplicate",
      "informational", "needs_clarification", "withdrawn", "addressed_by",
    ];
    expected.forEach((status) => {
      expect(triageBgClass(status)).toBe(`triage-bg--${status}`);
    });
  });
});
