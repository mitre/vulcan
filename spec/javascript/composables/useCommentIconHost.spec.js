import { describe, it, expect, vi } from "vitest";
import { ref, computed } from "vue";
import { useCommentIconHost } from "@/composables/useCommentIconHost";

describe("useCommentIconHost", () => {
  function setup(overrides = {}) {
    const rule = ref({
      reviews: [{ id: 1, action: "comment", section: "check_content" }],
      locked: false,
      ...overrides.rule,
    });
    const formGroupProps = computed(() => ({
      fields: { displayed: ["status"], disabled: [] },
      disabled: false,
      ...overrides.formGroupProps,
    }));
    const emit = vi.fn();

    return {
      ...useCommentIconHost({ rule, formGroupProps, emit }),
      emit,
      rule,
    };
  }

  describe("formGroupPropsWithCommentIcon", () => {
    it("spreads formGroupProps and adds showCommentIcon, ruleReviews, ruleLocked", () => {
      const { formGroupPropsWithCommentIcon } = setup();
      const props = formGroupPropsWithCommentIcon.value;

      expect(props.showCommentIcon).toBe(true);
      expect(props.ruleReviews).toEqual([{ id: 1, action: "comment", section: "check_content" }]);
      expect(props.ruleLocked).toBe(false);
      expect(props.fields).toEqual({ displayed: ["status"], disabled: [] });
    });

    it("reflects rule.locked changes reactively", () => {
      const { formGroupPropsWithCommentIcon, rule } = setup();
      expect(formGroupPropsWithCommentIcon.value.ruleLocked).toBe(false);
      rule.value = { ...rule.value, locked: true };
      expect(formGroupPropsWithCommentIcon.value.ruleLocked).toBe(true);
    });

    it("defaults reviews to empty array when rule has none", () => {
      const { formGroupPropsWithCommentIcon } = setup({ rule: { reviews: undefined } });
      expect(formGroupPropsWithCommentIcon.value.ruleReviews).toEqual([]);
    });
  });

  describe("commentIconProps (listeners-only mode)", () => {
    it("returns commentIconProps when formGroupProps is omitted", () => {
      const rule = ref({ reviews: [{ id: 1 }], locked: true });
      const emit = vi.fn();
      const result = useCommentIconHost({ rule, emit });
      expect(result.formGroupPropsWithCommentIcon).toBeNull();
      expect(result.commentIconProps.value).toEqual({
        showCommentIcon: true,
        ruleReviews: [{ id: 1 }],
        ruleLocked: true,
      });
    });
  });

  describe("commentIconListeners", () => {
    it("contains open-composer and view-comments handlers", () => {
      const { commentIconListeners } = setup();
      expect(commentIconListeners).toHaveProperty("open-composer");
      expect(commentIconListeners).toHaveProperty("view-comments");
      expect(typeof commentIconListeners["open-composer"]).toBe("function");
      expect(typeof commentIconListeners["view-comments"]).toBe("function");
    });

    it("open-composer handler emits open-composer with the section", () => {
      const { commentIconListeners, emit } = setup();
      commentIconListeners["open-composer"]("check_content");
      expect(emit).toHaveBeenCalledWith("open-composer", "check_content");
    });

    it("view-comments handler emits view-comments with the section", () => {
      const { commentIconListeners, emit } = setup();
      commentIconListeners["view-comments"]("fixtext");
      expect(emit).toHaveBeenCalledWith("view-comments", "fixtext");
    });
  });
});
