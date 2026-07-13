<template>
  <CommentList
    v-if="componentScoped || ruleId"
    :id="listId"
    :component-id="componentId"
    :filter-rule-id="componentScoped ? null : ruleId"
    :commentable-type="componentScoped ? 'component' : null"
    :highlight-section="componentScoped ? null : section"
    :max-rows="5"
    class="mb-3"
  >
    <template #header="{ rows, totalComments }">
      <b-alert v-if="totalComments > 0" show variant="info" class="mb-1">
        <button
          type="button"
          :aria-expanded="String(expanded)"
          :aria-controls="listId"
          class="btn btn-link p-0"
          @click="expanded = !expanded"
        >
          <span aria-hidden="true">ⓘ</span>
          {{ totalComments }} existing comment{{ totalComments === 1 ? "" : "s" }} on this
          {{ scopeNoun }}
          <template v-if="sectionDisplay">
            ({{ inSectionCount(rows) }} on {{ sectionDisplay }})
          </template>
          <span>{{ expanded ? "Hide ▴" : "Read first ▾" }}</span>
        </button>
      </b-alert>
    </template>

    <template #item="{ comment, dimmed, updateRow }">
      <div
        v-show="expanded"
        class="mb-2 rounded px-2 py-1 dedup-row"
        :class="{ 'dedup-dimmed': dimmed }"
      >
        <CommentItem
          :comment="comment"
          @toggle-reaction="(kind) => toggleReaction(comment, kind, updateRow)"
          @reply="$emit('reply', $event)"
        />
      </div>
    </template>
  </CommentList>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";
import CommentList from "../containers/CommentList.vue";
import CommentItem from "../shared/CommentItem.vue";
import { useCommentReactions } from "../../composables/useCommentReactions";

export default {
  name: "CommentDedupBanner",
  components: { CommentList, CommentItem },
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], default: null },
    section: { type: String, default: null },
    componentScoped: { type: Boolean, default: false },
  },
  setup() {
    const { toggle: toggleReactionApi } = useCommentReactions();
    return { toggleReactionApi };
  },
  data() {
    return { expanded: false };
  },
  computed: {
    sectionDisplay() {
      return this.section && !this.componentScoped ? sectionLabel(this.section) : "";
    },
    scopeNoun() {
      return this.componentScoped ? "component" : "rule";
    },
    listId() {
      return `dedup-list-${this.componentId}-${this.componentScoped ? "component" : this.ruleId}`;
    },
  },
  methods: {
    // How many of the loaded rows match the currently-selected section?
    // Surfaced in the alert header so commenters can see at a glance
    // whether prior conversation overlaps with what they're about to add.
    inSectionCount(rows) {
      if (!this.section) return 0;
      return rows.filter((r) => r.section === this.section).length;
    },
    toggleReaction(comment, kind, updateRow) {
      const prev = { ...comment.reactions };
      this.toggleReactionApi(comment.id, kind, prev, (reactions) => {
        updateRow(comment.id, { reactions });
      });
    },
  },
};
</script>

<style scoped>
.dedup-row {
  padding-left: 1rem;
}

/* De-emphasis floor is 0.85 (the app's recorded WCAG minimum) —
   dimmed rows must stay readable without hovering. */
.dedup-dimmed {
  opacity: 0.85;
}
</style>
