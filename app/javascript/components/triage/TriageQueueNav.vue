<template>
  <div class="triage-queue-nav d-flex align-items-center" role="navigation">
    <template v-if="comments.length > 0">
      <b-button
        data-testid="prev-comment"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasPrev"
        aria-label="Previous comment"
        class="mr-2"
        @click="goPrev"
      >
        <b-icon icon="chevron-left" />
      </b-button>

      <span class="small mr-2">
        <strong>{{ currentIndex + 1 }}</strong> of <strong>{{ comments.length }}</strong>
      </span>

      <b-button
        data-testid="next-comment"
        size="sm"
        variant="outline-secondary"
        :disabled="!hasNext"
        aria-label="Next comment"
        class="mr-3"
        @click="goNext"
      >
        <b-icon icon="chevron-right" />
      </b-button>

      <span class="small text-muted mr-3">{{ pendingCount }} pending</span>

      <b-dropdown
        data-testid="queue-dropdown"
        size="sm"
        variant="outline-secondary"
        text="Jump to..."
        no-caret
        class="queue-dropdown"
      >
        <b-dropdown-item
          v-for="comment in comments"
          :key="comment.id"
          data-testid="queue-dropdown-item"
          :active="comment.id === currentId"
          @click="$emit('select', comment.id)"
        >
          <span class="small">
            #{{ comment.id }}
            {{ comment.rule_displayed_name }}
          </span>
          <TriageStatusBadge
            :status="comment.triage_status"
            :adjudicated-at="comment.adjudicated_at"
            class="ml-2"
          />
        </b-dropdown-item>
      </b-dropdown>
    </template>

    <span v-else class="small text-muted">No comments</span>
  </div>
</template>

<script>
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";

export default {
  name: "TriageQueueNav",
  components: { TriageStatusBadge },
  props: {
    comments: { type: Array, required: true },
    currentId: { type: [Number, String], default: null },
  },
  computed: {
    currentIndex() {
      if (!this.currentId) return -1;
      return this.comments.findIndex((c) => c.id === this.currentId);
    },
    hasPrev() {
      return this.currentIndex > 0;
    },
    hasNext() {
      return this.currentIndex >= 0 && this.currentIndex < this.comments.length - 1;
    },
    pendingCount() {
      return this.comments.filter((c) => c.triage_status === "pending").length;
    },
  },
  methods: {
    goPrev() {
      if (this.hasPrev) {
        this.$emit("select", this.comments[this.currentIndex - 1].id);
      }
    },
    goNext() {
      if (this.hasNext) {
        this.$emit("select", this.comments[this.currentIndex + 1].id);
      }
    },
  },
};
</script>

<style scoped>
.queue-dropdown :deep(.dropdown-menu) {
  max-height: 300px;
  overflow-y: auto;
}
</style>
