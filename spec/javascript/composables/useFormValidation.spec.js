import { describe, it, expect, beforeEach } from "vitest";
import { useFormValidation, RULES } from "@/composables/useFormValidation";

// ─── Requirements ────────────────────────────────────────────
// 1. validate() touches all fields and returns true/false
// 2. fieldState() returns null (untouched), true (valid), false (invalid)
// 3. fieldError() returns error message only when touched
// 4. touch() marks a single field as interacted-with
// 5. reset() clears all touched state
// 6. isValid computed reflects current validity without touching
// 7. Rules: required, prefix, email, minLength, pattern, custom functions
// 8. Multiple rules on one field: first failure wins
// ─────────────────────────────────────────────────────────────

describe("useFormValidation", () => {
  // ─── Core API ─────────────────────────────────────────────

  describe("untouched fields", () => {
    it("fieldState returns null for untouched fields", () => {
      const { fieldState } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      expect(fieldState("name")).toBeNull();
    });

    it("fieldError returns empty string for untouched fields", () => {
      const { fieldError } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      expect(fieldError("name")).toBe("");
    });
  });

  describe("touch()", () => {
    it("marks a field as touched, enabling validation display", () => {
      const { fieldState, touch } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      touch("name");
      expect(fieldState("name")).toBe(false);
    });

    it("shows error message after touch", () => {
      const { fieldError, touch } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      touch("name");
      expect(fieldError("name")).toBe("This field is required");
    });

    it("shows valid state for valid touched field", () => {
      const { fieldState, touch } = useFormValidation({
        name: { value: () => "My Project", rules: { required: true } },
      });
      touch("name");
      expect(fieldState("name")).toBe(true);
    });
  });

  describe("validate()", () => {
    it("returns true when all fields are valid", () => {
      const { validate } = useFormValidation({
        name: { value: () => "Test", rules: { required: true } },
      });
      expect(validate()).toBe(true);
    });

    it("returns false when any field is invalid", () => {
      const { validate } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
        title: { value: () => "OK", rules: { required: true } },
      });
      expect(validate()).toBe(false);
    });

    it("touches all fields so errors become visible", () => {
      const { validate, fieldState } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
        title: { value: () => "", rules: { required: true } },
      });
      // Before validate, fields are untouched
      expect(fieldState("name")).toBeNull();
      validate();
      // After validate, fields show errors
      expect(fieldState("name")).toBe(false);
      expect(fieldState("title")).toBe(false);
    });
  });

  describe("reset()", () => {
    it("clears all touched state", () => {
      const { touch, reset, fieldState } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      touch("name");
      expect(fieldState("name")).toBe(false);
      reset();
      expect(fieldState("name")).toBeNull();
    });
  });

  describe("isValid (computed)", () => {
    it("returns true when all fields pass", () => {
      const { isValid } = useFormValidation({
        name: { value: () => "Test", rules: { required: true } },
      });
      expect(isValid.value).toBe(true);
    });

    it("returns false when any field fails", () => {
      const { isValid } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      expect(isValid.value).toBe(false);
    });

    it("does not require touching fields", () => {
      const { isValid, fieldState } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
      });
      // isValid reflects reality, fieldState still null (untouched)
      expect(isValid.value).toBe(false);
      expect(fieldState("name")).toBeNull();
    });
  });

  describe("errors()", () => {
    it("returns all current errors regardless of touched state", () => {
      const { errors } = useFormValidation({
        name: { value: () => "", rules: { required: true } },
        title: { value: () => "OK", rules: { required: true } },
        prefix: { value: () => "bad", rules: { required: true, prefix: true } },
      });
      const errs = errors();
      expect(errs.name).toBe("This field is required");
      expect(errs.title).toBeUndefined();
      expect(errs.prefix).toBe("Prefix must be of the form AAAA-00");
    });
  });

  // ─── Built-in Rules ───────────────────────────────────────

  describe("required rule", () => {
    it("fails for empty string", () => {
      expect(RULES.required("")).toBe("This field is required");
    });

    it("fails for whitespace-only string", () => {
      expect(RULES.required("   ")).toBe("This field is required");
    });

    it("fails for null", () => {
      expect(RULES.required(null)).toBe("This field is required");
    });

    it("fails for undefined", () => {
      expect(RULES.required(undefined)).toBe("This field is required");
    });

    it("passes for non-empty string", () => {
      expect(RULES.required("hello")).toBeNull();
    });
  });

  describe("prefix rule", () => {
    it("passes for valid prefix AAAA-00", () => {
      expect(RULES.prefix("RHEL-09")).toBeNull();
    });

    it("passes for alphanumeric + underscore", () => {
      expect(RULES.prefix("AB_D-0X")).toBeNull();
    });

    it("fails for too-short prefix", () => {
      expect(RULES.prefix("AB-01")).toBeTruthy();
    });

    it("fails for missing dash", () => {
      expect(RULES.prefix("ABCD01")).toBeTruthy();
    });

    it("fails for too many chars after dash", () => {
      expect(RULES.prefix("ABCD-012")).toBeTruthy();
    });

    it("returns null for empty (let required handle it)", () => {
      expect(RULES.prefix("")).toBeNull();
    });
  });

  describe("email rule", () => {
    it("passes for valid email", () => {
      expect(RULES.email("user@example.com")).toBeNull();
    });

    it("fails for missing @", () => {
      expect(RULES.email("userexample.com")).toBeTruthy();
    });

    it("fails for missing domain", () => {
      expect(RULES.email("user@")).toBeTruthy();
    });

    it("returns null for empty (let required handle it)", () => {
      expect(RULES.email("")).toBeNull();
    });
  });

  describe("minLength rule", () => {
    it("passes when value meets minimum", () => {
      const validator = RULES.minLength(5);
      expect(validator("hello")).toBeNull();
    });

    it("fails when value is too short", () => {
      const validator = RULES.minLength(5);
      expect(validator("hi")).toBe("Must be at least 5 characters");
    });

    it("returns null for empty (let required handle it)", () => {
      const validator = RULES.minLength(5);
      expect(validator("")).toBeNull();
    });
  });

  describe("pattern rule", () => {
    it("passes when value matches pattern", () => {
      const validator = RULES.pattern(/^\d{3}$/, "Must be 3 digits");
      expect(validator("123")).toBeNull();
    });

    it("fails with custom message", () => {
      const validator = RULES.pattern(/^\d{3}$/, "Must be 3 digits");
      expect(validator("12")).toBe("Must be 3 digits");
    });
  });

  // ─── Multiple rules ───────────────────────────────────────

  describe("multiple rules on one field", () => {
    it("required fires before prefix for empty value", () => {
      const { fieldError, touch } = useFormValidation({
        prefix: { value: () => "", rules: { required: true, prefix: true } },
      });
      touch("prefix");
      expect(fieldError("prefix")).toBe("This field is required");
    });

    it("prefix fires for non-empty invalid value", () => {
      const { fieldError, touch } = useFormValidation({
        prefix: { value: () => "bad", rules: { required: true, prefix: true } },
      });
      touch("prefix");
      expect(fieldError("prefix")).toBe("Prefix must be of the form AAAA-00");
    });

    it("both pass for valid value", () => {
      const { fieldState, touch } = useFormValidation({
        prefix: { value: () => "RHEL-09", rules: { required: true, prefix: true } },
      });
      touch("prefix");
      expect(fieldState("prefix")).toBe(true);
    });
  });

  // ─── Custom inline validators ─────────────────────────────

  describe("custom inline validator", () => {
    it("accepts a function as a rule", () => {
      const { fieldError, touch } = useFormValidation({
        age: {
          value: () => 15,
          rules: {
            custom: (v) => (v >= 18 ? null : "Must be 18 or older"),
          },
        },
      });
      touch("age");
      expect(fieldError("age")).toBe("Must be 18 or older");
    });

    it("returns null for passing custom rule", () => {
      const { fieldState, touch } = useFormValidation({
        age: {
          value: () => 21,
          rules: {
            custom: (v) => (v >= 18 ? null : "Must be 18 or older"),
          },
        },
      });
      touch("age");
      expect(fieldState("age")).toBe(true);
    });
  });

  // ─── Reactive value functions ─────────────────────────────

  describe("reactive value functions", () => {
    it("re-evaluates value function on each call", () => {
      let currentValue = "";
      const { fieldState, touch } = useFormValidation({
        name: { value: () => currentValue, rules: { required: true } },
      });
      touch("name");
      expect(fieldState("name")).toBe(false);

      currentValue = "Now filled";
      expect(fieldState("name")).toBe(true);
    });
  });

  // ─── Edge cases ───────────────────────────────────────────

  describe("edge cases", () => {
    it("fieldState returns null for unknown field", () => {
      const { fieldState } = useFormValidation({});
      expect(fieldState("nonexistent")).toBeNull();
    });

    it("fieldError returns empty for unknown field", () => {
      const { fieldError } = useFormValidation({});
      expect(fieldError("nonexistent")).toBe("");
    });

    it("handles field with no rules", () => {
      const { fieldState, touch } = useFormValidation({
        name: { value: () => "", rules: {} },
      });
      touch("name");
      expect(fieldState("name")).toBe(true);
    });

    it("handles disabled rules (required: false)", () => {
      const { fieldState, touch } = useFormValidation({
        name: { value: () => "", rules: { required: false } },
      });
      touch("name");
      expect(fieldState("name")).toBe(true);
    });
  });

  // ─── Real-world: Component form ───────────────────────────

  describe("component form scenario", () => {
    let form;
    let validation;

    beforeEach(() => {
      form = { name: "", prefix: "", title: "" };
      validation = useFormValidation({
        name: { value: () => form.name, rules: { required: true } },
        prefix: { value: () => form.prefix, rules: { required: true, prefix: true } },
        title: { value: () => form.title, rules: { required: true } },
      });
    });

    it("validate() fails when all fields empty", () => {
      expect(validation.validate()).toBe(false);
    });

    it("validate() passes with valid data", () => {
      form.name = "My Component";
      form.prefix = "RHEL-09";
      form.title = "Red Hat Enterprise Linux 9";
      expect(validation.validate()).toBe(true);
    });

    it("shows prefix format error for invalid prefix", () => {
      form.name = "Test";
      form.prefix = "bad";
      form.title = "Test";
      validation.validate();
      expect(validation.fieldError("prefix")).toBe("Prefix must be of the form AAAA-00");
      expect(validation.fieldState("name")).toBe(true);
    });

    it("reset clears errors after failed validation", () => {
      validation.validate();
      expect(validation.fieldState("name")).toBe(false);
      validation.reset();
      expect(validation.fieldState("name")).toBeNull();
    });
  });
});
