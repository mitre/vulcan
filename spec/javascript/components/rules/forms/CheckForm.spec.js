import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CheckForm from "@/components/rules/forms/CheckForm.vue";

vi.mock("@/composables/useFormFeedback", { spy: true });
import { useFormFeedback } from "@/composables/useFormFeedback";

/**
 * CheckForm Component Tests
 *
 * REQUIREMENTS:
 * - Renders the check fields (system, reference name/link, check text)
 *   from the rule's first checks_attributes entry — or from the
 *   satisfying parent when the rule is satisfied_by another rule.
 * - Input state classes derive via useFormFeedback, and the feedback
 *   objects pass through to RuleFormGroup (which renders the messages).
 */
describe("CheckForm", () => {
  let wrapper;

  const makeRule = (overrides = {}) => ({
    status: "Applicable - Configurable",
    satisfied_by: [],
    locked: false,
    review_requestor_id: null,
    checks_attributes: [
      {
        _destroy: false,
        system: "C-12345",
        content_ref_name: "M",
        content_ref_href: "http://example.com",
        content: "Verify the setting",
      },
    ],
    ...overrides,
  });

  const createWrapper = (props = {}) => {
    return mount(CheckForm, {
      localVue,
      propsData: {
        rule: makeRule(),
        index: 0,
        disabled: false,
        ...props,
      },
      stubs: {
        MarkdownTextarea: true,
        RuleFormGroup: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("check resolution", () => {
    it("reads the check from the rule's first checks_attributes entry", () => {
      wrapper = createWrapper();
      expect(wrapper.vm.check.system).toBe("C-12345");
      expect(wrapper.vm.check.content).toBe("Verify the setting");
    });

    it("reads the check from the satisfying parent when satisfied_by is set", () => {
      wrapper = createWrapper({
        rule: makeRule({
          satisfied_by: [
            { checks_attributes: [{ _destroy: false, content: "Parent check text" }] },
          ],
        }),
      });
      expect(wrapper.vm.check.content).toBe("Parent check text");
    });

    it("resolves to an empty object when the rule has no checks", () => {
      wrapper = createWrapper({ rule: makeRule({ checks_attributes: [] }) });
      expect(wrapper.vm.check).toEqual({});
    });
  });

  // ── composable contracts ────────────────────────────────────────────
  // REQUIREMENT: input state classes derive via useFormFeedback — no
  // FormFeedbackMixin remains. The validFeedback/invalidFeedback props
  // stay declared on the component (prop API parity with the mixin) and
  // pass through to RuleFormGroup for message rendering.
  describe("composable contracts", () => {
    it("derives input state classes via useFormFeedback", () => {
      wrapper = createWrapper({
        invalidFeedback: { content: "Check text is required" },
        validFeedback: { system: "System looks good" },
      });
      expect(useFormFeedback).toHaveBeenCalled();
      expect(wrapper.vm.inputClass("content")).toBe("is-invalid");
      expect(wrapper.vm.inputClass("system")).toBe("is-valid");
      expect(wrapper.vm.inputClass("content_ref_name")).toBe("");
    });

    it("passes the feedback objects through to RuleFormGroup", () => {
      wrapper = createWrapper({
        invalidFeedback: { content: "Check text is required" },
      });
      expect(wrapper.vm.formGroupProps.invalidFeedback).toEqual({
        content: "Check text is required",
      });
      expect(wrapper.vm.formGroupProps.validFeedback).toEqual({});
    });
  });
});
