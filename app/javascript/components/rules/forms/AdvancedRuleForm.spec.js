import { describe, test, expect } from "vitest";
import AdvancedRuleForm from "./AdvancedRuleForm.vue";

describe("AdvancedRuleForm", () => {
  function testComputed(computedName, props) {
    return AdvancedRuleForm.computed[computedName].bind(props);
  }

  const mockRule = {
    id: 1,
    rule_id: "000001",
    status: "Not Yet Determined",
    satisfied_by: [],
    satisfies: [],
    locked: false,
    review_requestor_id: null,
  };

  describe("disaDescriptionFormFields computed property", () => {
    test("shows all fields when status is Applicable - Configurable", () => {
      const computed = testComputed("disaDescriptionFormFields", {
        rule: { ...mockRule, status: "Applicable - Configurable", satisfied_by: [] },
      });

      const result = computed();
      expect(result.displayed).toContain("documentable");
      expect(result.displayed).toContain("vuln_discussion");
      expect(result.displayed).toContain("mitigations");
    });

    test("shows all fields when rule has satisfied_by relationships", () => {
      const computed = testComputed("disaDescriptionFormFields", {
        rule: {
          ...mockRule,
          status: "Not Yet Determined",
          satisfied_by: [{ id: 2 }],
        },
      });

      const result = computed();
      expect(result.displayed).toContain("documentable");
      expect(result.displayed).toContain("vuln_discussion");
      expect(result.displayed).toContain("mitigations");
    });

    test("shows only mitigation_control for Applicable - Does Not Meet without satisfied_by", () => {
      const computed = testComputed("disaDescriptionFormFields", {
        rule: { ...mockRule, status: "Applicable - Does Not Meet", satisfied_by: [] },
      });

      const result = computed();
      expect(result.displayed).toEqual(["mitigation_control"]);
    });
  });

  describe("ruleFormFields computed property", () => {
    test("shows full fields when status is Applicable - Configurable", () => {
      const computed = testComputed("ruleFormFields", {
        rule: { ...mockRule, status: "Applicable - Configurable", satisfied_by: [] },
      });

      const result = computed();
      expect(result.displayed).toContain("status");
      expect(result.displayed).toContain("title");
      expect(result.displayed).toContain("fixtext");
    });

    test("shows full fields when rule has satisfied_by relationships", () => {
      const computed = testComputed("ruleFormFields", {
        rule: {
          ...mockRule,
          status: "Not Yet Determined",
          satisfied_by: [{ id: 2 }],
        },
      });

      const result = computed();
      expect(result.displayed).toContain("status");
      expect(result.displayed).toContain("title");
      expect(result.displayed).toContain("fixtext");
    });

    test("disables title and fixtext when satisfied_by exists", () => {
      const computed = testComputed("ruleFormFields", {
        rule: {
          ...mockRule,
          status: "Applicable - Configurable",
          satisfied_by: [{ id: 2 }],
        },
      });

      const result = computed();
      expect(result.disabled).toContain("title");
      expect(result.disabled).toContain("fixtext");
    });
  });
});
