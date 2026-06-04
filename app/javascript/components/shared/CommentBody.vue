<template>
  <div class="comment-body">
    <b-badge v-if="isImported" variant="warning" class="mr-1">imported</b-badge>
    <small v-if="createdAt" class="text-muted">{{ friendlyDateTime(createdAt) }}</small>
    <div v-if="isLong" class="comment-body__text">
      {{ expanded ? text : text.substring(0, 200) + "…" }}
      <a href="#" class="text-primary ml-1" @click.prevent="expanded = !expanded">
        {{ expanded ? "show less" : "show more" }}
      </a>
    </div>
    <p v-else class="comment-body__text mb-1">{{ text }}</p>
  </div>
</template>

<script>
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";

export default {
  name: "CommentBody",
  mixins: [DateFormatMixin],
  props: {
    text: { type: String, default: "" },
    createdAt: { type: String, default: null },
    isImported: { type: Boolean, default: false },
  },
  data() {
    return { expanded: false };
  },
  computed: {
    isLong() {
      return this.text && this.text.length > 200;
    },
  },
};
</script>

<style scoped>
.comment-body__text {
  white-space: pre-wrap;
}
</style>
