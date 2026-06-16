<template>
  <b-modal
    id="merge-comments-modal"
    title="Merge comments"
    size="lg"
    centered
    no-close-on-backdrop
    ok-title="Merge"
    :ok-disabled="!canConfirm"
    @ok="confirm"
    @hidden="onHidden"
  >
    <p class="mb-3 small text-muted">
      Pick the survivor. Other comments will be marked
      <strong>duplicate</strong> of the survivor (not deleted) and link back to it from their rules.
    </p>
    <b-form-group label="Select survivor:" label-class="font-weight-bold">
      <div
        v-for="r in selectedReviews"
        :key="r.id"
        class="merge-row d-flex align-items-start mb-3 pb-2 border-bottom"
        data-testid="merge-row"
      >
        <b-form-radio
          v-model="survivorId"
          :value="r.id"
          :name="`merge-survivor-${_uid}`"
          class="mr-2"
          :aria-label="`Pick comment ${r.id} as survivor`"
          :data-testid="`merge-survivor-${r.id}`"
        />
        <div class="flex-grow-1">
          <small class="text-muted d-block">
            <strong>{{ r.rule_displayed_name }}</strong>
            · {{ r.author_name }}
            <span v-if="r.created_at"> · {{ formatDate(r.created_at) }}</span>
          </small>
          <div class="comment-preview small">{{ truncate(r.comment, 240) }}</div>
        </div>
      </div>
    </b-form-group>
    <small data-testid="merge-count" class="text-muted">
      {{ selectedReviews.length }} comments selected ({{ Math.max(selectedReviews.length - 1, 0) }}
      will become duplicates of the survivor).
    </small>
  </b-modal>
</template>

<script>
export default {
  name: "MergeCommentsModal",
  props: {
    selectedReviews: { type: Array, default: () => [] },
  },
  data() {
    return { survivorId: null };
  },
  computed: {
    canConfirm() {
      return this.selectedReviews.length >= 2 && this.survivorId != null;
    },
  },
  watch: {
    selectedReviews: {
      immediate: true,
      handler(reviews) {
        if (!reviews.length) {
          this.survivorId = null;
          return;
        }
        // Default to the oldest-posted comment per the card's Zendesk-style
        // UX recommendation (first instance = default survivor).
        const oldest = [...reviews].sort(
          (a, b) => new Date(a.created_at || 0) - new Date(b.created_at || 0),
        )[0];
        this.survivorId = oldest?.id ?? reviews[0].id;
      },
    },
  },
  methods: {
    truncate(s, n) {
      if (!s) return "";
      return s.length > n ? `${s.substring(0, n)}…` : s;
    },
    formatDate(iso) {
      try {
        return new Date(iso).toLocaleString();
      } catch {
        return "";
      }
    },
    confirm() {
      if (!this.canConfirm) return;
      this.$emit("submit", {
        review_ids: this.selectedReviews.map((r) => r.id),
        survivor_id: this.survivorId,
      });
      // b-modal auto-hides on @ok (we don't pass .prevent), so the parent
      // doesn't need to manage visibility — just react to @submit / @hidden.
    },
    onHidden() {
      this.$emit("hidden");
    },
  },
};
</script>
