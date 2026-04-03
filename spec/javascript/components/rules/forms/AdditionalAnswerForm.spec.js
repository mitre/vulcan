import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import AdditionalAnswerForm from "@/components/rules/forms/AdditionalAnswerForm.vue";

/**
 * AdditionalAnswerForm — B1 defensive init tests
 *
 * Verifies that the component handles rules where
 * additional_answers_attributes is undefined/null.
 */
describe("AdditionalAnswerForm", () => {
  let wrapper;

  const freeformQuestion = {
    id: 1,
    name: "Test Question",
    question_type: "freeform",
    options: [],
  };

  const urlQuestion = {
    id: 2,
    name: "Reference URL",
    question_type: "url",
    options: [],
  };

  const createWrapper = (props = {}) => {
    const w = mount(AdditionalAnswerForm, {
      localVue,
      propsData: {
        rule: { id: 1, additional_answers_attributes: [] },
        question: freeformQuestion,
        disabled: false,
        ...props,
      },
    });
    // Spy on the actual $root.$emit used by the component
    vi.spyOn(w.vm.$root, "$emit");
    return w;
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("defensive initialization (B1)", () => {
    it("handles rule with undefined additional_answers_attributes", () => {
      wrapper = createWrapper({
        rule: { id: 1 },
      });
      // Should not throw when finding answer text
      expect(wrapper.vm.findAnswerText(1)).toBeUndefined();
    });

    it("handles rule with null additional_answers_attributes", () => {
      wrapper = createWrapper({
        rule: { id: 1, additional_answers_attributes: null },
      });
      expect(wrapper.vm.findAnswerText(1)).toBeUndefined();
    });

    it("adds answer to empty/undefined attributes array", () => {
      const rule = { id: 1 };
      wrapper = createWrapper({ rule });

      wrapper.vm.addOrUpdateAnswer("my answer", 1);

      expect(wrapper.vm.$root.$emit).toHaveBeenCalledWith(
        "update:rule",
        expect.objectContaining({
          additional_answers_attributes: [{ additional_question_id: 1, answer: "my answer" }],
        }),
      );
    });
  });

  describe("answer operations", () => {
    it("updates existing answer", () => {
      const rule = {
        id: 1,
        additional_answers_attributes: [{ additional_question_id: 1, answer: "old" }],
      };
      wrapper = createWrapper({ rule });

      wrapper.vm.addOrUpdateAnswer("new answer", 1);

      expect(wrapper.vm.$root.$emit).toHaveBeenCalledWith(
        "update:rule",
        expect.objectContaining({
          additional_answers_attributes: [{ additional_question_id: 1, answer: "new answer" }],
        }),
      );
    });

    it("finds existing answer text", () => {
      wrapper = createWrapper({
        rule: {
          id: 1,
          additional_answers_attributes: [{ additional_question_id: 1, answer: "hello" }],
        },
      });
      expect(wrapper.vm.findAnswerText(1)).toBe("hello");
    });
  });

  describe("URL validation", () => {
    it("validates URL format for url question type", () => {
      wrapper = createWrapper({ question: urlQuestion });

      wrapper.vm.addOrUpdateAnswer("not-a-url", 2);
      expect(wrapper.vm.validurl).toBe(false);

      wrapper.vm.addOrUpdateAnswer("https://example.com", 2);
      expect(wrapper.vm.validurl).toBe(true);
    });

    it("accepts empty URL without validation error", () => {
      wrapper = createWrapper({ question: urlQuestion });
      wrapper.vm.addOrUpdateAnswer("", 2);
      expect(wrapper.vm.validurl).toBe(true);
    });
  });
});
