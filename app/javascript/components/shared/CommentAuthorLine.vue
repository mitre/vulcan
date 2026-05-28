<template>
  <div class="comment-author-line" :class="`comment-author-line--${layout}`">
    <template v-if="layout === 'block'">
      <p class="mb-0 text-muted small">
        <strong data-testid="author-name">{{ displayName }}</strong>
        <span v-if="email" data-testid="author-email"> ({{ email }})</span>
      </p>
      <p v-if="date" class="mb-0 text-muted small" data-testid="author-date">
        posted {{ friendlyDateTime(date) }}
      </p>
    </template>

    <template v-else-if="layout === 'cell'">
      <div data-testid="author-name">{{ displayName }}</div>
      <small v-if="email" class="text-muted" data-testid="author-email">{{ email }}</small>
    </template>

    <template v-else>
      <strong data-testid="author-name">{{ displayName }}</strong>
      <span v-if="email" data-testid="author-email"> ({{ email }})</span>
      <small v-if="date" class="text-muted ml-2" data-testid="author-date">
        {{ friendlyDateTime(date) }}
      </small>
    </template>
  </div>
</template>

<script>
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";

export default {
  name: "CommentAuthorLine",
  mixins: [DateFormatMixin],
  props: {
    name: { type: String, default: null },
    commenterDisplayName: { type: String, default: null },
    email: { type: String, default: null },
    date: { type: String, default: null },
    layout: {
      type: String,
      default: "inline",
      validator: (v) => ["inline", "block", "cell"].includes(v),
    },
  },
  computed: {
    displayName() {
      return this.name || this.commenterDisplayName || "—";
    },
  },
};
</script>
