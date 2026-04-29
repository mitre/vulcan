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
        {{ total }} existing
        <template v-if="sectionDisplay">{{ sectionDisplay }} </template>comment{{
          total === 1 ? "" : "s"
        }}
        on this rule.
        <span>{{ expanded ? "Hide ▴" : "Read first ▾" }}</span>
      </button>
    </b-alert>
    <ul v-show="expanded" :id="listId" class="list-unstyled mb-0 pl-3">
      <li v-for="row in rows" :key="row.id" class="mb-1">
        <strong>{{ row.author_name }}</strong>
        ({{ relativeTime(row.created_at) }}) — &quot;{{ truncate(row.comment, 100) }}&quot;
        <a href="#" @click.prevent="$emit('reply', row.id)">[Reply]</a>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";
import { sectionLabel } from "../../constants/triageVocabulary";

export default {
  name: "CommentDedupBanner",
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
  },
  watch: {
    section: { immediate: true, handler: "fetch" },
    ruleId: "fetch",
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
        const params = { rule_id: this.ruleId, triage_status: "all" };
        if (this.section) params.section = this.section;
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
