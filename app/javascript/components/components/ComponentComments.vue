<template>
  <div>
    <!-- Filter row -->
    <b-form-group class="mb-2">
      <b-input-group>
        <b-form-select
          v-model="filterStatus"
          :options="statusOptions"
          aria-label="Filter by triage status"
          style="max-width: 220px"
          @change="onFilterChanged"
        />
        <b-form-select
          v-model="filterSection"
          :options="sectionOptions"
          aria-label="Filter by section"
          class="ml-2"
          style="max-width: 220px"
          @change="onFilterChanged"
        />
        <b-form-input
          v-model="filterText"
          placeholder="Search comments..."
          debounce="300"
          aria-label="Search comment text"
          class="ml-2"
          @update="onFilterChanged"
        />
        <b-button
          v-b-tooltip.hover
          variant="outline-secondary"
          class="ml-2"
          aria-label="Refresh"
          title="Refresh"
          @click="fetch"
        >
          <b-icon icon="arrow-clockwise" />
        </b-button>
      </b-input-group>
    </b-form-group>

    <!-- Table -->
    <b-table
      :items="rows"
      :fields="fields"
      :busy="loading"
      sort-by="created_at"
      :sort-desc="true"
      hover
      striped
      small
      stacked="md"
      role="table"
      aria-label="Component comments triage queue"
    >
      <template #cell(rule_displayed_name)="{ item }">
        <a :href="ruleHref(item)">
          {{ item.rule_displayed_name }}
        </a>
      </template>
      <template #cell(component_name)="{ item }">
        <a :href="`/components/${item.component_id}/triage`">{{ item.component_name }}</a>
      </template>
      <template #cell(section)="{ value }">
        <!-- Use (general) label not em-dash for null section so a rule-level
             comment is clearly identified rather than looking like missing data. -->
        <SectionLabel :section="value" />
      </template>
      <template #cell(comment)="{ value }">
        <span :title="value">{{ truncate(value, 80) }}</span>
      </template>
      <template #cell(created_at)="{ value }">
        {{ friendlyDateTime(value) }}
      </template>
      <template #cell(triage_status)="{ item }">
        <TriageStatusBadge
          :status="item.triage_status"
          :adjudicated-at="item.adjudicated_at"
          :duplicate-of-id="item.duplicate_of_review_id"
        />
      </template>
      <template #cell(actions)="{ item }">
        <template v-if="canTriage">
          <b-button
            v-if="!item.adjudicated_at"
            size="sm"
            variant="outline-primary"
            @click="openTriageFor(item)"
          >
            {{ actionLabel(item) }}
          </b-button>
          <b-button
            v-else-if="item.triage_status !== 'withdrawn'"
            v-b-tooltip.hover
            size="sm"
            variant="outline-secondary"
            :aria-label="`Re-open comment ${item.id}`"
            title="Revert to 'decided but not closed' so the decision can be revised."
            @click="openReopen(item)"
          >
            <b-icon icon="arrow-counterclockwise" /> Re-open
          </b-button>
          <small
            v-else
            v-b-tooltip.hover
            class="text-muted font-italic"
            title="Withdrawn by the original commenter — only the commenter can re-open."
          >
            Commenter-only
          </small>
        </template>
        <small v-else class="text-muted font-italic" aria-label="Read-only role"> Read-only </small>
      </template>
      <template #table-busy>
        <div class="text-center py-3"><b-spinner small /> Loading…</div>
      </template>
      <template #empty>
        <div class="text-muted text-center py-3">No comments match these filters.</div>
      </template>
    </b-table>

    <!-- Pagination -->
    <div v-if="total > perPage" class="d-flex justify-content-center mt-2">
      <b-pagination
        v-model="page"
        :total-rows="total"
        :per-page="perPage"
        aria-label="Pagination"
        @input="fetch"
      />
    </div>

    <!-- Triage modal — fully implemented in Task 15 -->
    <CommentTriageModal
      :review="selectedRow"
      @triaged="onTriaged"
      @adjudicated="onAdjudicated"
      @hidden="selectedRow = null"
    />
  </div>
</template>

<script>
import axios from "axios";
import { TRIAGE_LABELS, SECTION_LABELS } from "../../constants/triageVocabulary";
import AlertMixin from "../../mixins/AlertMixin.vue";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";
import CommentTriageModal from "./CommentTriageModal.vue";

export default {
  name: "ComponentComments",
  components: { TriageStatusBadge, SectionLabel, CommentTriageModal },
  mixins: [AlertMixin, DateFormatMixin, RoleComparisonMixin],
  props: {
    // Either componentId (single-component scope) or projectId (aggregate
    // scope) is required — but not both. The scope prop disambiguates and
    // selects the correct backend endpoint.
    componentId: { type: [Number, String], default: null },
    projectId: { type: [Number, String], default: null },
    scope: {
      type: String,
      default: "component",
      validator: (v) => ["component", "project"].includes(v),
    },
    // Server-resolved role on this project/component. Viewers see the
    // triage queue but cannot mutate — author+ can triage / adjudicate
    // / re-open. Mirrors the backend authorize_author_project gates.
    effectivePermissions: { type: String, default: null },
  },
  data() {
    const persisted = this.loadPersistedFilters();
    const fields = [
      { key: "id", label: "#", sortable: false },
      { key: "rule_displayed_name", label: "Rule", sortable: true },
    ];
    // Project-scope view spans multiple components — show a Component
    // column so triagers know which component each row belongs to.
    if (this.scope === "project") {
      fields.push({ key: "component_name", label: "Component", sortable: true });
    }
    fields.push(
      { key: "section", label: "Section", sortable: true },
      { key: "author_name", label: "Author", sortable: true },
      { key: "comment", label: "Comment", sortable: false },
      { key: "created_at", label: "Posted", sortable: true },
      { key: "triage_status", label: "Status", sortable: true },
      { key: "actions", label: "Action", sortable: false, tdClass: "text-nowrap" },
    );
    return {
      rows: [],
      total: 0,
      page: 1,
      perPage: 25,
      loading: false,
      filterText: persisted.filterText,
      filterStatus: persisted.filterStatus,
      filterSection: persisted.filterSection,
      selectedRow: null,
      fields,
    };
  },
  computed: {
    // Triagers (author+) get the mutating action buttons; viewers get
    // a read-only label. Server enforces the same gate via
    // authorize_author_project on the /reviews/:id/* endpoints.
    canTriage() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    statusOptions() {
      const friendly = Object.entries(TRIAGE_LABELS)
        .filter(([value]) => value !== "pending")
        .map(([value, text]) => ({ value, text }));
      return [
        { value: "all", text: "All statuses" },
        { value: "pending", text: "Pending" },
        ...friendly,
      ];
    },
    sectionOptions() {
      const friendly = Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text }));
      return [
        { value: null, text: "All sections" },
        { value: "(general)", text: "(general)" },
        ...friendly,
      ];
    },
  },
  mounted() {
    this.fetch();
  },
  methods: {
    // Identifier used for localStorage filter persistence. Disambiguates
    // component-scope vs project-scope so a user's filter on component 42
    // doesn't override their filter on project 42 (different IDs, different
    // namespaces). Implemented as a method (not a computed) so it can be
    // called from data() during component init, before computeds resolve.
    scopeKey() {
      const id = this.scope === "project" ? this.projectId : this.componentId;
      return `${this.scope}-${id}`;
    },
    persistKey() {
      return `commentTriageFilters-${this.scopeKey()}`;
    },
    loadPersistedFilters() {
      const fallback = { filterStatus: "pending", filterSection: null, filterText: "" };
      try {
        const raw = localStorage.getItem(this.persistKey());
        if (!raw) return fallback;
        const parsed = JSON.parse(raw);
        return {
          filterStatus: parsed.filterStatus ?? fallback.filterStatus,
          filterSection: parsed.filterSection ?? fallback.filterSection,
          filterText: parsed.filterText ?? fallback.filterText,
        };
      } catch (_e) {
        return fallback;
      }
    },
    persistFilters() {
      try {
        localStorage.setItem(
          this.persistKey(),
          JSON.stringify({
            filterStatus: this.filterStatus,
            filterSection: this.filterSection,
            filterText: this.filterText,
          }),
        );
      } catch (_e) {
        // localStorage full or disabled — non-fatal, filters just won't persist
      }
    },
    truncate(text, n) {
      if (!text) return "";
      return text.length > n ? `${text.slice(0, n)}…` : text;
    },
    onFilterChanged() {
      this.page = 1;
      this.persistFilters();
      this.fetch();
    },
    async fetch() {
      this.loading = true;
      try {
        const params = {
          page: this.page,
          per_page: this.perPage,
          triage_status: this.filterStatus,
        };
        if (this.filterText) params.q = this.filterText;
        if (this.filterSection && this.filterSection !== "(general)") {
          params.section = this.filterSection;
        }
        const url =
          this.scope === "project"
            ? `/projects/${this.projectId}/comments`
            : `/components/${this.componentId}/comments`;
        const { data } = await axios.get(url, { params });
        this.rows = data.rows;
        this.total = data.pagination.total;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.loading = false;
      }
    },
    // Rule-id link target — full-page navigates to the component editor
    // with the rule selected (Vulcan's existing rule deep-link format).
    // Encode the rule name segment so that unusual characters can't break
    // out of the path or silently navigate elsewhere.
    ruleHref(row) {
      const compId = this.scope === "project" ? row.component_id : this.componentId;
      return `/components/${compId}/${encodeURIComponent(row.rule_displayed_name)}`;
    },
    openTriageFor(row) {
      this.selectedRow = row;
      this.$bvModal.show("comment-triage-modal");
    },
    // Button label clarifies the lifecycle stage: pending → triage,
    // already-triaged but not yet adjudicated → "Edit / Close" makes
    // editability obvious (was previously labeled just "Close" which
    // misleadingly implied finalize-only).
    actionLabel(row) {
      if (row.triage_status === "pending") return "Triage";
      return "Edit / Close";
    },
    async openReopen(row) {
      try {
        const { data } = await axios.patch(`/reviews/${row.id}/reopen`);
        // Server returns the updated Review hash on the `review` key.
        if (data && data.review) {
          this.alertOrNotifyResponse({
            data: {
              toast: {
                title: "Re-opened",
                message: ["Decision is editable again."],
                variant: "success",
              },
            },
          });
        }
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.fetch();
      }
    },
    onTriaged() {
      this.fetch();
    },
    onAdjudicated() {
      this.fetch();
    },
  },
};
</script>
