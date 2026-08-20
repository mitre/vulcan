import { describe, it, expect } from "vitest";
import { ruleArray } from "@/utils/ruleArray";

// The omit-keys convention, executable: authored SRG payloads omit the
// Rule-only array keys their kind does not carry, so the accessor must
// hand every consumer an array no matter which payload shape arrived.
describe("ruleArray", () => {
  it("returns the array when the key is present", () => {
    const rule = { satisfies: [{ id: 1 }] };
    expect(ruleArray(rule, "satisfies")).toBe(rule.satisfies);
  });

  it("returns an empty array when the key is omitted (authored payload)", () => {
    expect(ruleArray({}, "checks_attributes")).toEqual([]);
  });

  it("returns an empty array when the key is null", () => {
    expect(ruleArray({ satisfied_by: null }, "satisfied_by")).toEqual([]);
  });

  it("returns an empty array when the rule itself is null or undefined", () => {
    expect(ruleArray(null, "satisfies")).toEqual([]);
    expect(ruleArray(undefined, "disa_rule_descriptions_attributes")).toEqual([]);
  });
});
