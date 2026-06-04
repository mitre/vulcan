<template>
  <div v-if="totalComments > 0" class="mb-3">
    <b-alert show variant="info" class="mb-1">
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
        <template v-if="sectionDisplay"> ({{ inSection }} on {{ sectionDisplay }}) </template>
        <span>{{ expanded ? "Hide ▴" : "Read first ▾" }}</span>
      </button>
    </b-alert>
    <ul v-show="expanded" :id="listId" class="list-unstyled mb-0 pl-3">
      <li
        v-for="row in rows"
        :key="row.id"
        class="mb-2 rounded px-2 py-1"
        :class="{ 'dedup-dimmed': isDimmed(row) }"
      >
        <CommentItem
          :comment="row"
          @toggle-reaction="(kind) => toggleReaction(row, kind)"
          @reply="$emit('reply', $event)"
        />
      </li>
    </ul>
  </div>
</template>

<script>
import { sectionLabel } from "../../constants/triageVocabulary";
import CommentItem from "../shared/CommentItem.vue";
import { useCommentReactions } from "../../composables/useCommentReactions";
import { useCommentsStore } from "../../stores/comments";

export default {
  name: "CommentDedupBanner",
  components: { CommentItem },
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], default: null },
    section: { type: String, default: null },
    componentScoped: { type: Boolean, default: false },
  },
  setup() {
    const { toggle: toggleReactionApi } = useCommentReactions();
    const store = useCommentsStore();
    return { toggleReactionApi, store };
  },
  data() {
    return { rows: [], total: 0, totalComments: 0, expanded: false };
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
    // How many of the loaded rows match the currently-selected section?
    // Surfaced in the alert header so commenters can see at a glance
    // whether prior conversation overlaps with what they're about to add.
    inSection() {
      if (!this.section) return 0;
      return this.rows.filter((r) => r.section === this.section).length;
    },
  },
  watch: {
    // Refetch on rule change OR scope flip (rule ↔ component); section
    // change does NOT refetch (we always load all comments at the current
    // scope and let the user see prior context across sections —
    // section-specific count is shown via inSection).
    ruleId: { immediate: true, handler: "fetch" },
    componentScoped: "fetch",
  },
  methods: {
    isDimmed(row) {
      if (!this.section || this.componentScoped) return false;
      return row.section !== this.section;
    },
    async fetch() {
      try {
        const params = { triage_status: "all" };
        if (this.componentScoped) {
          params.commentable_type = "component";
        } else if (this.ruleId) {
          params.rule_id = this.ruleId;
        } else {
          this.rows = [];
          this.total = 0;
          this.totalComments = 0;
          return;
        }
        const result = await this.store.fetchComments(this.componentId, params);
        this.rows = (result.rows ?? []).slice(0, 5);
        this.total = result.pagination?.total ?? 0;
        this.totalComments = result.pagination?.total_comments ?? result.pagination?.total ?? 0;
      } catch {
        this.rows = [];
        this.total = 0;
        this.totalComments = 0;
      }
    },
    toggleReaction(row, kind) {
      const idx = this.rows.findIndex((r) => r.id === row.id);
      if (idx < 0) return;
      const prev = { ...row.reactions };
      const apply = (reactions) => {
        this.$set(this.rows, idx, { ...this.rows[idx], reactions });
      };
      this.toggleReactionApi(row.id, kind, prev, apply);
    },
  },
};
</script>

<style scoped>
.dedup-dimmed {
  opacity: 0.45;
  transition: opacity 0.15s ease;
}

.dedup-dimmed:hover {
  opacity: 0.85;
}
</style>
