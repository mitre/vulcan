import { describe, it, expect } from "vitest";
import { useSortRules } from "../../../app/javascript/composables/useSortRules";

describe("useSortRules", () => {
  const { compareRules } = useSortRules();

  it("returns -1 when first rule_id is less than second", () => {
    expect(compareRules({ rule_id: "00001" }, { rule_id: "00002" })).toBe(-1);
  });

  it("returns 1 when first rule_id is greater than second", () => {
    expect(compareRules({ rule_id: "00002" }, { rule_id: "00001" })).toBe(1);
  });

  it("returns 0 when rule_ids are equal", () => {
    expect(compareRules({ rule_id: "00001" }, { rule_id: "00001" })).toBe(0);
  });

  it("sorts an array of rules correctly", () => {
    const rules = [
      { rule_id: "00003" },
      { rule_id: "00001" },
      { rule_id: "00002" },
    ];
    const sorted = [...rules].sort(compareRules);
    expect(sorted.map((r) => r.rule_id)).toEqual(["00001", "00002", "00003"]);
  });
});
