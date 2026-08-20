import { ref, computed, nextTick } from "vue";

/**
 * useReplyComposer — unified composer state for CommentComposerModal (Vue 2.7)
 *
 * Replaces ReplyComposerMixin. One composerState object covers all three
 * composer modes (reply, new-comment, component) instead of the two divergent
 * row-based / id-based patterns that preceded the mixin.
 *
 * Instance APIs become injected callbacks:
 *   - onOpen: fired after nextTick when any open* method runs. The mixin
 *     hard-wired $bvModal.show("comment-composer-modal"); each consumer now
 *     decides its show mechanism ($bvModal in hybrid components, a template
 *     ref, or v-model visibility).
 *   - afterPosted(parentReviewId, stateSnapshot): replaces the mixin's
 *     afterComposerPosted override hook — screen-specific refresh logic
 *     (fetch, rule reload, etc.). snapshot is the composerState before clear.
 *
 * Key-set parity: the open methods build state objects with the SAME key
 * sets as the mixin (reply/component modes omit parentRuleId/parentRuleName
 * entirely, so composerProps yields undefined for them — and Vue prop
 * defaults apply on undefined, not null).
 *
 * Usage:
 *   setup(props, { emit }) {
 *     const composer = useReplyComposer({
 *       onOpen: () => root.$bvModal.show("comment-composer-modal"),
 *       afterPosted: (parentReviewId, snapshot) => fetchComments(),
 *     });
 *     return { ...composer };
 *   }
 *
 * @param {Object} [options]
 * @param {Function} [options.onOpen] - Called after nextTick on each open*
 * @param {Function} [options.afterPosted] - Called with (parentReviewId, snapshot) on post
 * @returns {Object} Reactive state, computeds, and methods
 */
export function useReplyComposer({ onOpen, afterPosted } = {}) {
  const composerState = ref(emptyState());

  function emptyState() {
    return {
      mode: null,
      reviewId: null,
      ruleId: null,
      componentId: null,
      section: null,
      ruleName: null,
      parentRuleId: null,
      parentRuleName: null,
    };
  }

  const composerActive = computed(() => composerState.value.mode !== null);

  const composerProps = computed(() => {
    const s = composerState.value;
    return {
      componentId: s.componentId,
      ruleId: s.ruleId,
      ruleDisplayedName: s.ruleName,
      initialSection: s.section,
      replyToReviewId: s.reviewId,
      parentRuleId: s.parentRuleId,
      parentRuleName: s.parentRuleName,
    };
  });

  function show() {
    if (onOpen) {
      nextTick(() => onOpen());
    }
  }

  function openReplyComposer({ reviewId, ruleId, componentId, ruleName }) {
    composerState.value = {
      mode: "reply",
      reviewId,
      ruleId: ruleId || null,
      componentId: componentId || null,
      section: null,
      ruleName: ruleName || null,
    };
    show();
  }

  function openSectionComposer({
    ruleId,
    componentId,
    section,
    ruleName,
    parentRuleId,
    parentRuleName,
  }) {
    composerState.value = {
      mode: "new-comment",
      reviewId: null,
      ruleId: ruleId || null,
      componentId: componentId || null,
      section: section || null,
      ruleName: ruleName || null,
      parentRuleId: parentRuleId || null,
      parentRuleName: parentRuleName || null,
    };
    show();
  }

  function openComponentComposer(componentId) {
    composerState.value = {
      mode: "component",
      reviewId: null,
      ruleId: null,
      componentId,
      section: null,
      ruleName: null,
    };
    show();
  }

  function closeComposer() {
    composerState.value = emptyState();
  }

  function onComposerPosted() {
    const snapshot = { ...composerState.value };
    closeComposer();
    if (afterPosted) {
      afterPosted(snapshot.reviewId || null, snapshot);
    }
  }

  function onComposerHidden() {
    closeComposer();
  }

  return {
    // State
    composerState,
    composerActive,
    composerProps,
    // Methods
    openReplyComposer,
    openSectionComposer,
    openComponentComposer,
    closeComposer,
    onComposerPosted,
    onComposerHidden,
  };
}
