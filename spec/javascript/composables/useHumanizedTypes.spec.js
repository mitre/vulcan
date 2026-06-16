import { describe, it, expect } from "vitest";
import {
  useHumanizedTypes,
  HUMANIZED_TYPES,
} from "../../../app/javascript/composables/useHumanizedTypes";

describe("useHumanizedTypes", () => {
  const { humanizedType } = useHumanizedTypes();

  it("maps BaseRule to Rule", () => {
    expect(humanizedType("BaseRule")).toBe("Rule");
  });

  it("maps RuleDescription to Rule Description", () => {
    expect(humanizedType("RuleDescription")).toBe("Rule Description");
  });

  it("maps vuln_discussion to Vulnerability Discussion", () => {
    expect(humanizedType("vuln_discussion")).toBe("Vulnerability Discussion");
  });

  it("maps fixtext to Fix Text", () => {
    expect(humanizedType("fixtext")).toBe("Fix Text");
  });

  it("maps status to Status", () => {
    expect(humanizedType("status")).toBe("Status");
  });

  it("returns the original string for unknown types", () => {
    expect(humanizedType("some_unknown_field")).toBe("some_unknown_field");
  });

  it("returns the original string for null/undefined", () => {
    expect(humanizedType(null)).toBeNull();
    expect(humanizedType(undefined)).toBeUndefined();
  });
});

describe("HUMANIZED_TYPES constant", () => {
  it("contains expected mappings", () => {
    expect(HUMANIZED_TYPES.BaseRule).toBe("Rule");
    expect(HUMANIZED_TYPES.locked).toBe("Locked");
    expect(HUMANIZED_TYPES.content).toBe("Check");
  });
});
