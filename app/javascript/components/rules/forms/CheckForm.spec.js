import { describe, test, expect } from "vitest";
import CheckForm from "./CheckForm.vue";

describe("CheckForm", () => {
  function testComputed(computedName, props) {
    return CheckForm.computed[computedName].bind(props);
  }

  const mockRule = {
    id: 1,
    status: "Not Yet Determined",
    satisfied_by: [],
    checks_attributes: [{ id: 1, content: "Test check" }],
  };

  describe("tooltips computed property", () => {
    test("shows correct tooltip for Applicable - Configurable status", () => {
      const computed = testComputed("tooltips", {
        rule: { ...mockRule, status: "Applicable - Configurable", satisfied_by: [] },
      });

      const result = computed();
      expect(result.content).toBe(
        "Describe how to validate that the remediation has been properly implemented",
      );
    });

    test("shows correct tooltip when rule has satisfied_by (treated as configurable)", () => {
      const computed = testComputed("tooltips", {
        rule: {
          ...mockRule,
          status: "Not Yet Determined",
          satisfied_by: [{ id: 2 }],
        },
      });

      const result = computed();
      expect(result.content).toBe(
        "Describe how to validate that the remediation has been properly implemented",
      );
    });

    test("shows different tooltip for other statuses without satisfied_by", () => {
      const computed = testComputed("tooltips", {
        rule: { ...mockRule, status: "Not Yet Determined", satisfied_by: [] },
      });

      const result = computed();
      expect(result.content).toBe("Describe how to check for the presence of the vulnerability");
    });

    test("shows null tooltip for Applicable - Inherently Meets", () => {
      const computed = testComputed("tooltips", {
        rule: { ...mockRule, status: "Applicable - Inherently Meets", satisfied_by: [] },
      });

      const result = computed();
      expect(result.content).toBeNull();
    });
  });
});
