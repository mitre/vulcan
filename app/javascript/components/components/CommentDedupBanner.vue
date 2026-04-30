<template>
  <div v-if="total > 0" class="mb-3">
    <b-alert show variant="info" class="mb-1">
      <button
        type="button"
        :aria-expanded="String(expanded)"
        :aria-controls="listId"
        class="btn btn-link p-0"
        @click="expanded = !expanded"
      >
        <span aria-hidden="true">ⓘ</span>
        {{ total }} existing comment{{ total === 1 ? "" : "s" }} on this rule
        <template v-if="sectionDisplay"> ({{ inSection }} on {{ sectionDisplay }}) </template>
        <span>{{ expanded ? "Hide ▴" : "Read first ▾" }}</span>
      </button>
    </b-alert>
    <ul v-show="expanded" :id="listId" class="list-unstyled mb-0 pl-3">
      <li v-for="row in rows" :key="row.id" class="mb-1">
        <strong>{{ row.author_name }}</strong>
        <SectionLabel v-if="row.section" :section="row.section" class="badge badge-light ml-1" />
        ({{ relativeTime(row.created_at) }}) — &quot;{{ truncate(row.comment, 100) }}&quot;
        <a href="#" @click.prevent="$emit('reply', row.id)">[Reply]</a>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";
import { sectionLabel } from "../../constants/triageVocabulary";
import SectionLabel from "../shared/SectionLabel.vue";

export default {
  name: "CommentDedupBanner",
  components: { SectionLabel },
  props: {
    componentId: { type: [Number, String], required: true },
    ruleId: { type: [Number, String], required: true },
    section: { type: String, default: null },
  },
  data() {
    return { rows: [], total: 0, expanded: false };
  },
  computed: {
    sectionDisplay() {
      return this.section ? sectionLabel(this.section) : "";
    },
    listId() {
      return `dedup-list-${this.componentId}-${this.ruleId}`;
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
    // Refetch on rule change; section change does NOT refetch (we always
    // load all rule-level comments and let the user see prior context
    // across sections — section-specific count is shown via inSection).
    ruleId: { immediate: true, handler: "fetch" },
  },
  methods: {
    truncate(s, n) {
      return s && s.length > n ? `${s.slice(0, n)}…` : s;
    },
    relativeTime(iso) {
      return iso ? new Date(iso).toLocaleDateString() : "";
    },
    async fetch() {
      try {
        // Fetch ALL rule-level comments regardless of section so the
        // commenter sees prior conversation across the whole rule (not
        // just the section they happen to have selected). Section-scoped
        // count is computed client-side via the inSection computed.
        const params = { rule_id: this.ruleId, triage_status: "all" };
        const { data } = await axios.get(`/components/${this.componentId}/comments`, {
          params,
        });
        this.rows = data.rows.slice(0, 5);
        this.total = data.pagination.total;
      } catch {
        this.rows = [];
        this.total = 0;
      }
    },
  },
};
</script>
