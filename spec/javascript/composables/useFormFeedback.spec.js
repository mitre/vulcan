import { describe, it, expect } from "vitest";
import { reactive } from "vue";
import { useFormFeedback } from "../../../app/javascript/composables/useFormFeedback";

// REQUIREMENT: useFormFeedback must replicate FormFeedbackMixin behavior exactly.
// The mixin mapped two object props (validFeedback / invalidFeedback, keyed by
// field name) to Bootstrap input classes:
//   - invalid feedback present  → "is-invalid"  (invalid WINS over valid)
//   - valid feedback present    → "is-valid"
//   - neither                   → ""
// Presence is hasOwnProperty semantics — a key with an empty-string value still
// counts as feedback (parity with `this.validFeedback.hasOwnProperty(field)`).
describe("useFormFeedback", () => {
  describe("hasValidFeedback", () => {
    it("returns true when the field has valid feedback", () => {
      const props = { validFeedback: { name: "Looks good" }, invalidFeedback: {} };
      const { hasValidFeedback } = useFormFeedback(props);
      expect(hasValidFeedback("name")).toBe(true);
    });

    it("returns false when the field has no valid feedback", () => {
      const props = { validFeedback: { name: "Looks good" }, invalidFeedback: {} };
      const { hasValidFeedback } = useFormFeedback(props);
      expect(hasValidFeedback("other_field")).toBe(false);
    });

    it("counts a key with a falsy value as present (hasOwnProperty parity)", () => {
      const props = { validFeedback: { name: "" }, invalidFeedback: {} };
      const { hasValidFeedback } = useFormFeedback(props);
      expect(hasValidFeedback("name")).toBe(true);
    });
  });

  describe("hasInvalidFeedback", () => {
    it("returns true when the field has invalid feedback", () => {
      const props = { validFeedback: {}, invalidFeedback: { prefix: "Bad format" } };
      const { hasInvalidFeedback } = useFormFeedback(props);
      expect(hasInvalidFeedback("prefix")).toBe(true);
    });

    it("returns false when the field has no invalid feedback", () => {
      const props = { validFeedback: {}, invalidFeedback: { prefix: "Bad format" } };
      const { hasInvalidFeedback } = useFormFeedback(props);
      expect(hasInvalidFeedback("name")).toBe(false);
    });
  });

  describe("inputClass", () => {
    it("returns is-invalid when the field has invalid feedback", () => {
      const props = { validFeedback: {}, invalidFeedback: { content: "Required" } };
      const { inputClass } = useFormFeedback(props);
      expect(inputClass("content")).toBe("is-invalid");
    });

    it("returns is-valid when the field has only valid feedback", () => {
      const props = { validFeedback: { content: "Saved" }, invalidFeedback: {} };
      const { inputClass } = useFormFeedback(props);
      expect(inputClass("content")).toBe("is-valid");
    });

    it("invalid wins over valid when both are present (mixin precedence parity)", () => {
      const props = {
        validFeedback: { content: "Saved" },
        invalidFeedback: { content: "But now broken" },
      };
      const { inputClass } = useFormFeedback(props);
      expect(inputClass("content")).toBe("is-invalid");
    });

    it("returns empty string when the field has no feedback", () => {
      const props = { validFeedback: {}, invalidFeedback: {} };
      const { inputClass } = useFormFeedback(props);
      expect(inputClass("content")).toBe("");
    });
  });

  describe("missing feedback objects (mixin prop-default parity)", () => {
    it("treats undefined validFeedback as empty", () => {
      const props = { invalidFeedback: {} };
      const { hasValidFeedback, inputClass } = useFormFeedback(props);
      expect(hasValidFeedback("name")).toBe(false);
      expect(inputClass("name")).toBe("");
    });

    it("treats undefined invalidFeedback as empty", () => {
      const props = { validFeedback: {} };
      const { hasInvalidFeedback, inputClass } = useFormFeedback(props);
      expect(hasInvalidFeedback("name")).toBe(false);
      expect(inputClass("name")).toBe("");
    });
  });

  describe("reactivity", () => {
    it("reflects updates to a reactive props source", () => {
      const props = reactive({ validFeedback: {}, invalidFeedback: {} });
      const { inputClass, hasInvalidFeedback } = useFormFeedback(props);

      expect(inputClass("name")).toBe("");

      props.invalidFeedback = { name: "Server rejected" };
      expect(hasInvalidFeedback("name")).toBe(true);
      expect(inputClass("name")).toBe("is-invalid");

      props.invalidFeedback = {};
      props.validFeedback = { name: "Accepted" };
      expect(inputClass("name")).toBe("is-valid");
    });
  });
});
