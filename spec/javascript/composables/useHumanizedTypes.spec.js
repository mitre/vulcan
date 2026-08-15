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

  describe("kind-keyed noun entries", () => {
    it("srg document_type renders Requirement-flavored labels", () => {
      const { humanizedType: srgHumanized } = useHumanizedTypes("srg");
      expect(srgHumanized("BaseRule")).toBe("Requirement");
      expect(srgHumanized("RuleDescription")).toBe("Requirement Description");
      expect(srgHumanized("rule_severity")).toBe("Requirement Severity");
      // Non-noun entries are untouched.
      expect(srgHumanized("locked")).toBe("Locked");
    });

    it("accepts a getter and keeps the stig default without one", () => {
      const { humanizedType: fromGetter } = useHumanizedTypes(() => "srg");
      expect(fromGetter("rule_id")).toBe("Requirement ID");
      const { humanizedType: noKind } = useHumanizedTypes();
      expect(noKind("rule_id")).toBe("Rule ID");
    });
  });
});
