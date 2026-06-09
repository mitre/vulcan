import { describe, it, expect, vi } from "vitest";
import { nextTick } from "vue";
import { useReplyComposer } from "@/composables/useReplyComposer";

// REQUIREMENT: useReplyComposer must replicate ReplyComposerMixin exactly —
// the unified composerState for CommentComposerModal consumers (reply,
// new-comment, and component modes), the composerProps mapping, and the
// posted/hidden lifecycle.
//
// Instance APIs are replaced with injected callbacks:
//   - onOpen: called after nextTick when an open* method fires (the mixin
//     called $bvModal.show("comment-composer-modal") — Phase 2 consumers
//     decide their own show mechanism)
//   - afterPosted(parentReviewId, stateSnapshot): replaces the mixin's
//     afterComposerPosted override hook
//
// Key-set parity matters: the mixin's open methods build objects with
// DIFFERENT key sets (reply/component modes omit parentRuleId/parentRuleName
// entirely → undefined). Vue prop defaults apply on undefined but NOT null,
// so the exact shapes are pinned here.
describe("useReplyComposer", () => {
  describe("initial state", () => {
    it("starts inactive with all fields null", () => {
      const { composerState, composerActive } = useReplyComposer();
      expect(composerActive.value).toBe(false);
      expect(composerState.value).toEqual({
        mode: null,
        reviewId: null,
        ruleId: null,
        componentId: null,
        section: null,
        ruleName: null,
        parentRuleId: null,
        parentRuleName: null,
      });
    });
  });

  describe("openReplyComposer", () => {
    it("sets reply mode with the given fields and activates", () => {
      const { openReplyComposer, composerState, composerActive } = useReplyComposer();

      openReplyComposer({ reviewId: 7, ruleId: 3, componentId: 12, ruleName: "SRG-001" });

      expect(composerActive.value).toBe(true);
      expect(composerState.value).toEqual({
        mode: "reply",
        reviewId: 7,
        ruleId: 3,
        componentId: 12,
        section: null,
        ruleName: "SRG-001",
      });
    });

    it("defaults missing optional fields to null (mixin parity)", () => {
      const { openReplyComposer, composerState } = useReplyComposer();

      openReplyComposer({ reviewId: 7 });

      expect(composerState.value.ruleId).toBe(null);
      expect(composerState.value.componentId).toBe(null);
      expect(composerState.value.ruleName).toBe(null);
    });

    it("calls onOpen after nextTick, not synchronously", async () => {
      const onOpen = vi.fn();
      const { openReplyComposer } = useReplyComposer({ onOpen });

      openReplyComposer({ reviewId: 7 });
      expect(onOpen).not.toHaveBeenCalled();

      await nextTick();
      expect(onOpen).toHaveBeenCalledTimes(1);
    });
  });

  describe("openSectionComposer", () => {
    it("sets new-comment mode with all eight fields", () => {
      const { openSectionComposer, composerState } = useReplyComposer();

      openSectionComposer({
        ruleId: 3,
        componentId: 12,
        section: "check_content",
        ruleName: "SRG-001",
        parentRuleId: 9,
        parentRuleName: "SRG-PARENT",
      });

      expect(composerState.value).toEqual({
        mode: "new-comment",
        reviewId: null,
        ruleId: 3,
        componentId: 12,
        section: "check_content",
        ruleName: "SRG-001",
        parentRuleId: 9,
        parentRuleName: "SRG-PARENT",
      });
    });

    it("defaults missing fields to null", () => {
      const { openSectionComposer, composerState } = useReplyComposer();

      openSectionComposer({ ruleId: 3 });

      expect(composerState.value.section).toBe(null);
      expect(composerState.value.parentRuleId).toBe(null);
      expect(composerState.value.parentRuleName).toBe(null);
    });
  });

  describe("openComponentComposer", () => {
    it("sets component mode with only the componentId", () => {
      const { openComponentComposer, composerState, composerActive } = useReplyComposer();

      openComponentComposer(12);

      expect(composerActive.value).toBe(true);
      expect(composerState.value).toEqual({
        mode: "component",
        reviewId: null,
        ruleId: null,
        componentId: 12,
        section: null,
        ruleName: null,
      });
    });

    it("calls onOpen after nextTick", async () => {
      const onOpen = vi.fn();
      const { openComponentComposer } = useReplyComposer({ onOpen });

      openComponentComposer(12);
      await nextTick();
      expect(onOpen).toHaveBeenCalledTimes(1);
    });
  });

  describe("composerProps", () => {
    it("maps composerState to CommentComposerModal prop names", () => {
      const { openSectionComposer, composerProps } = useReplyComposer();

      openSectionComposer({
        ruleId: 3,
        componentId: 12,
        section: "fixtext",
        ruleName: "SRG-001",
        parentRuleId: 9,
        parentRuleName: "SRG-PARENT",
      });

      expect(composerProps.value).toEqual({
        componentId: 12,
        ruleId: 3,
        ruleDisplayedName: "SRG-001",
        initialSection: "fixtext",
        replyToReviewId: null,
        parentRuleId: 9,
        parentRuleName: "SRG-PARENT",
      });
    });

    it("yields undefined parent fields in reply mode (key-set parity for Vue prop defaults)", () => {
      const { openReplyComposer, composerProps } = useReplyComposer();

      openReplyComposer({ reviewId: 7, ruleId: 3, componentId: 12, ruleName: "SRG-001" });

      expect(composerProps.value.replyToReviewId).toBe(7);
      expect(composerProps.value.parentRuleId).toBe(undefined);
      expect(composerProps.value.parentRuleName).toBe(undefined);
    });
  });

  describe("closeComposer", () => {
    it("resets every field to null and deactivates", () => {
      const { openSectionComposer, closeComposer, composerState, composerActive } =
        useReplyComposer();
      openSectionComposer({ ruleId: 3, componentId: 12, parentRuleId: 9 });

      closeComposer();

      expect(composerActive.value).toBe(false);
      expect(composerState.value).toEqual({
        mode: null,
        reviewId: null,
        ruleId: null,
        componentId: null,
        section: null,
        ruleName: null,
        parentRuleId: null,
        parentRuleName: null,
      });
    });
  });

  describe("onComposerPosted", () => {
    it("calls afterPosted with the reviewId and a pre-close snapshot, then clears state", () => {
      const afterPosted = vi.fn();
      const { openReplyComposer, onComposerPosted, composerActive } = useReplyComposer({
        afterPosted,
      });
      openReplyComposer({ reviewId: 7, ruleId: 3, componentId: 12, ruleName: "SRG-001" });

      onComposerPosted();

      expect(afterPosted).toHaveBeenCalledTimes(1);
      const [parentReviewId, snapshot] = afterPosted.mock.calls[0];
      expect(parentReviewId).toBe(7);
      expect(snapshot.mode).toBe("reply");
      expect(snapshot.componentId).toBe(12);
      expect(composerActive.value).toBe(false);
    });

    it("passes null parentReviewId for new-comment mode (no reviewId)", () => {
      const afterPosted = vi.fn();
      const { openSectionComposer, onComposerPosted } = useReplyComposer({ afterPosted });
      openSectionComposer({ ruleId: 3, componentId: 12 });

      onComposerPosted();

      expect(afterPosted).toHaveBeenCalledTimes(1);
      expect(afterPosted.mock.calls[0][0]).toBe(null);
      expect(afterPosted.mock.calls[0][1].mode).toBe("new-comment");
    });

    it("is safe without an afterPosted callback (mixin no-op parity)", () => {
      const { openReplyComposer, onComposerPosted, composerActive } = useReplyComposer();
      openReplyComposer({ reviewId: 7 });

      expect(() => onComposerPosted()).not.toThrow();
      expect(composerActive.value).toBe(false);
    });
  });

  describe("onComposerHidden", () => {
    it("clears state without calling afterPosted", () => {
      const afterPosted = vi.fn();
      const { openReplyComposer, onComposerHidden, composerActive } = useReplyComposer({
        afterPosted,
      });
      openReplyComposer({ reviewId: 7 });

      onComposerHidden();

      expect(afterPosted).not.toHaveBeenCalled();
      expect(composerActive.value).toBe(false);
    });
  });
});
