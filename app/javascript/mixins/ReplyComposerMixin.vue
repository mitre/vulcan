<script>
// Unified composer state management for CommentComposerModal consumers.
// Replaces two divergent patterns (row-based and id-based) with a single
// composerState object. Consumers override afterComposerPosted() for
// screen-specific refresh logic (fetch, rule reload, etc.).
//
// Requires: $bvModal (Bootstrap-Vue modal control) on the host component.
export default {
  data() {
    return {
      composerState: {
        mode: null,
        reviewId: null,
        ruleId: null,
        componentId: null,
        section: null,
        ruleName: null,
      },
    };
  },
  computed: {
    composerActive() {
      return this.composerState.mode !== null;
    },
    composerProps() {
      const s = this.composerState;
      return {
        componentId: s.componentId,
        ruleId: s.ruleId,
        ruleDisplayedName: s.ruleName,
        initialSection: s.section,
        replyToReviewId: s.reviewId,
      };
    },
  },
  methods: {
    openReplyComposer({ reviewId, ruleId, componentId, ruleName }) {
      this.composerState = {
        mode: "reply",
        reviewId,
        ruleId: ruleId || null,
        componentId: componentId || null,
        section: null,
        ruleName: ruleName || null,
      };
      this.$nextTick(() => this.$bvModal.show("comment-composer-modal"));
    },
    openSectionComposer({ ruleId, componentId, section, ruleName }) {
      this.composerState = {
        mode: "new-comment",
        reviewId: null,
        ruleId: ruleId || null,
        componentId: componentId || null,
        section: section || null,
        ruleName: ruleName || null,
      };
      this.$nextTick(() => this.$bvModal.show("comment-composer-modal"));
    },
    openComponentComposer(componentId) {
      this.composerState = {
        mode: "component",
        reviewId: null,
        ruleId: null,
        componentId,
        section: null,
        ruleName: null,
      };
      this.$nextTick(() => this.$bvModal.show("comment-composer-modal"));
    },
    closeComposer() {
      this.composerState = {
        mode: null,
        reviewId: null,
        ruleId: null,
        componentId: null,
        section: null,
        ruleName: null,
      };
    },
    onComposerPosted() {
      const parentReviewId = this.composerState.reviewId || null;
      this.closeComposer();
      this.afterComposerPosted(parentReviewId);
    },
    onComposerHidden() {
      this.closeComposer();
    },
    afterComposerPosted() {
      // No-op — consumers override with screen-specific refresh logic
    },
  },
};
</script>
