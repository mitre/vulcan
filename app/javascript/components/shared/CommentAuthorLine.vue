<template>
  <div class="comment-author-line" :class="`comment-author-line--${layout}`">
    <template v-if="layout === 'block'">
      <div class="d-flex align-items-center mb-1">
        <UserBadge :name="displayName" :email="email" :show-name="true" />
      </div>
      <p v-if="date" class="mb-0 text-muted small" data-testid="author-date">
        posted {{ friendlyDateTime(date) }}
      </p>
    </template>

    <template v-else-if="layout === 'cell'">
      <div class="d-flex align-items-center">
        <UserBadge :name="displayName" :email="email" :show-name="true" />
      </div>
    </template>

    <template v-else>
      <UserBadge :name="displayName" :email="email" />
      <small v-if="date" class="text-muted ml-2" data-testid="author-date">
        {{ friendlyDateTime(date) }}
      </small>
    </template>
  </div>
</template>

<script>
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import UserBadge from "./UserBadge.vue";

export default {
  name: "CommentAuthorLine",
  components: { UserBadge },
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
