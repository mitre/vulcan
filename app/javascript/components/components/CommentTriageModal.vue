<template>
  <!--
    Placeholder. Task 15 (15-frontend-comment-triage-modal.md) implements the
    full triage decision modal here. ComponentComments (Task 14) renders
    this as a child so wiring + parent <-> child events are testable now.
  -->
  <b-modal id="comment-triage-modal" :title="title" hide-footer @hidden="$emit('hidden')">
    <div v-if="review" class="text-muted small">
      Triage UI coming in Task 15. Selected review #{{ review.id }}.
    </div>
  </b-modal>
</template>

<script>
export default {
  name: "CommentTriageModal",
  props: {
    review: { type: Object, default: null },
  },
  computed: {
    title() {
      return this.review ? `Triage comment #${this.review.id}` : "Triage";
    },
  },
};
</script>
