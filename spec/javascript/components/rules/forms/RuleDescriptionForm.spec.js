import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleDescriptionForm from "@/components/rules/forms/RuleDescriptionForm.vue";

vi.mock("@/composables/useFormFeedback", { spy: true });
import { useFormFeedback } from "@/composables/useFormFeedback";

/**
 * RuleDescriptionForm Component Tests
 *
 * REQUIREMENTS:
 * - Renders the Rule Description editor unless the description is
 *   marked for destruction (_destroy).
 * - Input state class and the valid/invalid feedback messages derive
 *   via useFormFeedback from the validFeedback/invalidFeedback props.
 */
describe("RuleDescriptionForm", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(RuleDescriptionForm, {
      localVue,
      propsData: {
        description: { _destroy: false, description: "A rule description" },
        rule: { id: 1 },
        index: 0,
        disabled: false,
        ...props,
      },
      stubs: {
        MarkdownTextarea: true,
        InfoTooltip: true,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("rendering", () => {
    it("renders the description form group", () => {
      wrapper = createWrapper();
      expect(wrapper.text()).toContain("Rule Description");
    });

    it("renders nothing when the description is marked for destruction", () => {
      wrapper = createWrapper({
        description: { _destroy: true, description: "going away" },
      });
      expect(wrapper.text()).not.toContain("Rule Description");
    });
  });

  // ── composable contracts ────────────────────────────────────────────
  // REQUIREMENT: input state classes + feedback visibility derive via
  // useFormFeedback — no FormFeedbackMixin remains. The props stay
  // declared on the component (prop API parity with the mixin).
  describe("composable contracts", () => {
    it("derives input state classes via useFormFeedback", () => {
      wrapper = createWrapper({
        invalidFeedback: { description: "Description is required" },
      });
      expect(useFormFeedback).toHaveBeenCalled();
      expect(wrapper.vm.inputClass("description")).toBe("is-invalid");
    });

    it("renders the invalid feedback message for the description field", () => {
      wrapper = createWrapper({
        invalidFeedback: { description: "Description is required" },
      });
      expect(wrapper.find(".invalid-feedback").text()).toBe("Description is required");
      expect(wrapper.find(".valid-feedback").exists()).toBe(false);
    });

    it("renders the valid feedback message for the description field", () => {
      wrapper = createWrapper({
        validFeedback: { description: "Looks good" },
      });
      expect(wrapper.find(".valid-feedback").text()).toBe("Looks good");
      expect(wrapper.find(".invalid-feedback").exists()).toBe(false);
    });

    it("renders no feedback when none is supplied", () => {
      wrapper = createWrapper();
      expect(wrapper.find(".valid-feedback").exists()).toBe(false);
      expect(wrapper.find(".invalid-feedback").exists()).toBe(false);
    });
  });
});
