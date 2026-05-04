<template>
  <div>
    <b-form-input
      v-model="query"
      placeholder="Search by author, rule, or comment text..."
      debounce="300"
      aria-label="Search canonical candidates"
      size="sm"
      class="mb-2"
    />
    <div v-if="loading" class="text-muted small">
      <b-spinner small />
      Loading candidates…
    </div>
    <!-- Sonar Web:S6842: <li role="button"> assigns an
         interactive role to a non-interactive element. Use the
         listbox/option pattern instead — role="option" is allowed on
         <li> inside <ul role="listbox"> per ARIA 1.2. -->
    <ul
      v-else
      role="listbox"
      class="list-unstyled mb-0"
      style="max-height: 280px; overflow-y: auto"
    >
      <li v-if="filteredRows.length === 0" class="text-muted small font-italic px-1">
        No matching canonical candidates.
      </li>
      <li
        v-for="row in filteredRows"
        :key="row.id"
        :data-test="`canonical-candidate-${row.id}`"
        class="border rounded p-2 mb-1 canonical-candidate"
        :class="{ 'border-primary bg-light': Number(selectedReviewId) === row.id }"
        role="option"
        :aria-selected="Number(selectedReviewId) === row.id"
        tabindex="0"
        @click="$emit('selected', row.id)"
        @keydown.enter="$emit('selected', row.id)"
      >
        <div>
          <strong>#{{ row.id }} — {{ row.rule_displayed_name }}</strong>
          <SectionLabel v-if="row.section" :section="row.section" class="badge badge-light ml-1" />
          <small class="text-muted ml-2">{{ row.author_name }}</small>
        </div>
        <div class="small text-muted">{{ truncate(row.comment, 120) }}</div>
      </li>
    </ul>
  </div>
</template>

<script>
import axios from "axios";
import SectionLabel from "../shared/SectionLabel.vue";

// Picker for the "duplicate of" target on the triage modal. Scoped to the
// same component as the comment being marked (server enforces this via
// duplicate_of_must_be_same_component). Excludes the self row + any row
// that is itself a duplicate (defense in depth — server's
// duplicate_of_must_not_be_a_duplicate validator is authoritative).
export default {
  name: "CanonicalCommentPicker",
  components: { SectionLabel },
  props: {
    componentId: { type: [Number, String], required: true },
    excludeReviewId: { type: [Number, String], required: true },
    selectedReviewId: { type: [Number, String], default: null },
  },
  data() {
    return { rows: [], loading: false, query: "" };
  },
  computed: {
    filteredRows() {
      const q = (this.query || "").toLowerCase().trim();
      const exclude = Number(this.excludeReviewId);
      return this.rows
        .filter((r) => r.id !== exclude)
        .filter((r) => r.triage_status !== "duplicate")
        .filter((r) => {
          if (!q) return true;
          return (
            (r.comment || "").toLowerCase().includes(q) ||
            (r.author_name || "").toLowerCase().includes(q) ||
            (r.rule_displayed_name || "").toLowerCase().includes(q)
          );
        });
    },
  },
  watch: {
    query() {
      // Server already filters by comment text — drive the same backend
      // request when the search box changes so we don't blow up to all
      // comments client-side.
      this.fetch();
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    truncate(s, n) {
      if (!s) return "";
      return s.length > n ? `${s.slice(0, n)}…` : s;
    },
    async fetch() {
      this.loading = true;
      try {
        const params = { triage_status: "all", per_page: 25 };
        if (this.query) params.q = this.query;
        const { data } = await axios.get(`/components/${this.componentId}/comments`, { params });
        this.rows = data.rows || [];
      } catch (err) {
        // Log so a backend 500 / auth error / network failure is visible
        // in the console instead of silently zeroing the row list — which
        // looks identical to "no comments match" to the user.
        // eslint-disable-next-line no-console
        console.error("CanonicalCommentPicker: failed to fetch candidates", err);
        this.rows = [];
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>

<style scoped>
.canonical-candidate {
  cursor: pointer;
  transition: background-color 0.1s;
}
.canonical-candidate:hover {
  background-color: var(--bs-light, #f8f9fa);
}
</style>
