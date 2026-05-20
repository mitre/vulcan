<template>
  <div>
    <!-- Filter row. Uses shared FilterDropdown so menus stay in viewport
         even in narrow panels / slideovers (native <select> ignores
         boundary props and clips at viewport edges). -->
    <div class="d-flex flex-wrap align-items-center mb-2" style="gap: 0.5rem">
      <FilterDropdown
        v-model="filterStatus"
        :options="statusOptions"
        aria-label="Filter by triage status"
        @input="onFilterChanged"
      />
      <FilterDropdown
        v-if="splitModeFilterVisible"
        v-model="filterSection"
        :options="sectionOptions"
        aria-label="Filter by section"
        @input="onFilterChanged"
      />
      <b-form-input
        v-if="splitModeFilterVisible"
        v-model="filterText"
        placeholder="Search comments..."
        debounce="300"
        aria-label="Search comment text"
        size="sm"
        style="max-width: 240px"
        @update="onFilterChanged"
      />
      <b-button
        v-b-tooltip.hover
        variant="outline-secondary"
        size="sm"
        aria-label="Refresh"
        title="Refresh"
        @click="fetch"
      >
        <b-icon icon="arrow-clockwise" />
      </b-button>
      <b-button
        v-if="canExportDisposition"
        v-b-tooltip.hover
        :href="dispositionExportUrl"
        variant="outline-secondary"
        size="sm"
        aria-label="Export disposition matrix CSV"
        title="Export DISA disposition matrix (CSV) — passes through the active status filter"
      >
        <b-icon icon="download" /> Export CSV
      </b-button>
      <b-form-checkbox
        v-model="showResolved"
        switch
        size="sm"
        class="ml-auto mr-3"
        data-testid="show-resolved-toggle"
      >
        <small class="text-muted">Show resolved</small>
      </b-form-checkbox>
      <b-button-group v-if="!splitMode" size="sm">
        <b-button
          v-b-tooltip.hover
          :variant="viewMode === 'table' ? 'secondary' : 'outline-secondary'"
          title="Table view"
          aria-label="Table view"
          data-testid="view-mode-table"
          @click="setViewMode('table')"
        >
          <b-icon icon="table" />
        </b-button>
        <b-button
          v-b-tooltip.hover
          :variant="viewMode === 'by-rule' ? 'secondary' : 'outline-secondary'"
          title="Group by rule"
          aria-label="Group by rule"
          data-testid="view-mode-by-rule"
          @click="setViewMode('by-rule')"
        >
          <b-icon icon="list-nested" />
        </b-button>
      </b-button-group>
      <b-button
        v-if="canCommentOnComponent"
        variant="primary"
        size="sm"
        aria-label="Add component-level comment"
        @click="openComponentComposerLocal"
      >
        <b-icon icon="chat-left-text" /> Comment
      </b-button>
    </div>

    <!-- Split-pane triage view. Replaces table+modal with side-by-side
         rule content + triage form. Entered by clicking "Triage" on a row. -->
    <TriageSplitView
      v-if="splitMode"
      :rows="rows"
      :initial-comment-id="splitCommentId"
      :component-id="componentId"
      :effective-permissions="effectivePermissions"
      :admin-panel-open="adminPanelOpen"
      :context-mode="contextMode"
      @update:contextMode="$emit('update:contextMode', $event)"
      @exit="exitSplitMode"
      @triaged="onTriaged"
      @adjudicated="onAdjudicated"
      @response-posted="onTriageResponsePosted"
      @destroyed="onDestroyed"
      @reaction-updated="updateRowInPlace"
      @open-reply-composer="openReplyComposerFromRow"
      @admin-panel-close="$emit('admin-panel-close')"
    />

    <!-- By-rule grouped view -->
    <CommentsByRule
      v-else-if="viewMode === 'by-rule'"
      :rows="rows"
      @reaction-updated="updateRowInPlace"
    />

    <!-- Table -->
    <b-table
      v-else
      :items="rows"
      :fields="fields"
      :busy="loading"
      :sort-by.sync="sortBy"
      :sort-desc.sync="sortDesc"
      primary-key="id"
      hover
      striped
      small
      stacked="md"
      show-empty
      role="table"
      aria-label="Component comments table"
    >
      <template #cell(rule_displayed_name)="{ item }">
        <!-- data-turbolinks="false" forces a full page load. Without it,
             turbolinks navigates to the rule editor but the project_component
             pack registers its turbolinks:load listener after the event has
             already fired, so Vue never mounts and the page is blank. -->
        <span v-if="item.commentable_type === 'Component'" class="text-muted font-italic">
          {{ item.rule_displayed_name }}
        </span>
        <a v-else :href="ruleHref(item)" data-turbolinks="false">
          {{ item.rule_displayed_name }}
        </a>
      </template>
      <template #cell(component_name)="{ item }">
        <a :href="`/components/${item.component_id}/triage`" data-turbolinks="false">
          {{ item.component_name }}
        </a>
      </template>
      <template #cell(section)="{ item, value }">
        <!-- Use (general) label not em-dash for null section so a rule-level
             comment is clearly identified rather than looking like missing data. -->
        <SectionLabel :section="value" :commentable-type="item.commentable_type" />
      </template>
      <template #cell(comment)="{ item, value }">
        <div class="comment-text">{{ value }}</div>
        <CommentThread
          :ref="`thread-${item.id}`"
          :parent-review-id="item.id"
          :responses-count="item.responses_count || 0"
          :can-reply="canReply"
          class="mt-1"
          @reply="openReplyComposerFromRow(item)"
        />
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

    <CommentComposerModal
      v-if="composerActive"
      v-bind="composerProps"
      :component-displayed-name="composerState.mode === 'component' ? componentDisplayedName : ''"
      @posted="onComposerPosted"
      @hidden="onComposerHidden"
    />
  </div>
</template>

<script>
import axios from "axios";
import { SECTION_LABELS, buildStatusFilterOptions } from "../../constants/triageVocabulary";
import AlertMixin from "../../mixins/AlertMixin.vue";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import FormMixin from "../../mixins/FormMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";
import FilterDropdown from "../shared/FilterDropdown.vue";
import CommentThread from "../shared/CommentThread.vue";
import TriageSplitView from "../triage/TriageSplitView.vue";
import CommentComposerModal from "./CommentComposerModal.vue";
import CommentsByRule from "./CommentsByRule.vue";
import ReplyComposerMixin from "../../mixins/ReplyComposerMixin.vue";

export default {
  name: "ComponentComments",
  components: {
    TriageStatusBadge,
    SectionLabel,
    FilterDropdown,
    CommentThread,
    TriageSplitView,
    CommentComposerModal,
    CommentsByRule,
  },
  // FormMixin sets axios.defaults['X-CSRF-Token'] on mount. Required because
  // each esbuild pack has its own axios singleton (bundle isolation) — the
  // navbar pack's FormMixin doesn't reach the consuming pack. The reopen
  // PATCH would 422 on CSRF in a pack that lacks pack-level CSRF setup.
  mixins: [AlertMixin, DateFormatMixin, FormMixin, RoleComparisonMixin, ReplyComposerMixin],
  props: {
    // Either componentId (single-component scope) or projectId (aggregate
    // scope) is required — but not both. The scope prop disambiguates and
    // selects the correct backend endpoint.
    componentId: { type: [Number, String], default: null },
    componentDisplayedName: { type: String, default: "" },
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
    adminPanelOpen: { type: Boolean, default: false },
    contextMode: { type: String, default: "commented" },
  },
  data() {
    const persisted = this.loadPersistedFilters();
    const fields = [
      { key: "id", label: "#", sortable: true },
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
      // .sync-bound to b-table so column-header clicks update state and
      // the active sort-direction arrow renders. BootstrapVue 2 only
      // shows the arrow when sortBy/sortDesc are controlled.
      sortBy: "id",
      sortDesc: false,
      splitMode: false,
      splitCommentId: null,
      viewMode: this.loadPersistedViewMode(),
      fields,
    };
  },
  computed: {
    // Triagers (author+) get the mutating action buttons; viewers get
    // a read-only label. Server enforces the same gate via
    // authorize_author_project on the /reviews/:id/* endpoints.
    showResolved: {
      get() {
        return this.filterStatus === "all";
      },
      set(val) {
        this.filterStatus = val ? "all" : "pending";
        this.onFilterChanged();
      },
    },
    canTriage() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    splitModeFilterVisible() {
      return !this.splitMode;
    },
    // Anyone authenticated with project visibility can reply during an
    // open comment window. Server enforces via reject_if_comments_closed
    // and authorize_viewer_project; the affordance shows even on closed
    // components and the resulting click surfaces the rejection toast
    // rather than silently disabling, matching the never-hide-features
    // pattern used for SectionCommentIcon.
    canReply() {
      return !!this.effectivePermissions;
    },
    canCommentOnComponent() {
      return this.scope === "component" && this.componentId != null && this.canReply;
    },
    // Author-tier+ gate; server enforces author-tier minimum + admin-only include_email.
    canExportDisposition() {
      if (!this.canTriage) return false;
      if (this.scope === "component") return this.componentId != null;
      if (this.scope === "project") return this.projectId != null;
      return false;
    },
    dispositionExportUrl() {
      const base =
        this.scope === "project"
          ? `/projects/${this.projectId}/export/disposition_csv`
          : `/components/${this.componentId}/export/disposition_csv`;
      if (!this.filterStatus || this.filterStatus === "all") return base;
      return `${base}?triage_status=${encodeURIComponent(this.filterStatus)}`;
    },
    statusOptions() {
      return buildStatusFilterOptions();
    },
    sectionOptions() {
      const friendly = Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text }));
      return [
        { value: null, text: "All sections" },
        { value: "(general)", text: "Overall Requirement" },
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
    viewModeKey() {
      return `commentTriageViewMode-${this.scopeKey()}`;
    },
    loadPersistedViewMode() {
      try {
        const mode = localStorage.getItem(this.viewModeKey());
        return mode === "by-rule" ? "by-rule" : "table";
      } catch {
        return "table";
      }
    },
    setViewMode(mode) {
      this.viewMode = mode;
      try {
        localStorage.setItem(this.viewModeKey(), mode);
      } catch {
        // Non-fatal
      }
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
      } catch (e) {
        // Corrupt or missing storage — log + fall back to defaults.
        // eslint-disable-next-line no-console
        console.warn("ComponentComments: filter restore failed", e);
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
      } catch (e) {
        // Non-fatal — storage full or disabled (e.g. private browsing).
        // eslint-disable-next-line no-console
        console.warn("ComponentComments: filter persistence failed", e);
      }
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
        if (this.splitMode) params.include_rule_content = true;
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
      this.splitCommentId = row.id;
      this.splitMode = true;
      this.$emit("split-mode-changed", true);
      this.fetch();
    },
    exitSplitMode() {
      this.splitMode = false;
      this.splitCommentId = null;
      this.$emit("split-mode-changed", false);
      this.fetch();
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
    // modal events update the matching
    // row in place from the response payload rather than refetching the
    // whole table. Eliminates the second round trip per mutation. The
    // expanded ReviewBlueprint default fields (rule_id, section,
    // responding_to_review_id, duplicate_of_review_id, triage_set_by_id,
    // triager/adjudicator/commenter display fields) carry enough state
    // to keep the row visually consistent with the table's row shape.
    // `rule_displayed_name` is computed in paginated_comments (prefix +
    // rule_id) and not in the blueprint — preserved via spread merge.
    // Falls back to fetch when the payload is missing (defensive).
    updateRowInPlace(updatedReview) {
      if (!updatedReview || !updatedReview.id) {
        this.fetch();
        return;
      }
      const idx = this.rows.findIndex((r) => r.id === updatedReview.id);
      if (idx < 0) {
        this.fetch();
        return;
      }
      this.rows.splice(idx, 1, { ...this.rows[idx], ...updatedReview });
    },
    onTriaged(payload) {
      this.updateRowInPlace(payload);
    },
    onAdjudicated(payload) {
      this.updateRowInPlace(payload);
    },
    // Fired after a triage decision that included a response_comment —
    // server creates a child Review atomically. Bump the parent row's
    // responses_count so CommentThread's watcher auto-refreshes.
    onTriageResponsePosted({ parentId }) {
      const idx = this.rows.findIndex((r) => r.id === parentId);
      if (idx < 0) return;
      const row = this.rows[idx];
      this.rows.splice(idx, 1, {
        ...row,
        responses_count: (row.responses_count || 0) + 1,
      });
    },
    // admin hard-delete destroys the review entirely;
    // refresh the queue so the destroyed row (and its replies) disappear.
    onDestroyed() {
      this.fetch();
    },
    openReplyComposerFromRow(row) {
      this.openReplyComposer({
        reviewId: row.id,
        ruleId: row.rule_id,
        componentId: row.component_id || this.componentId,
        ruleName: row.rule_displayed_name,
      });
    },
    openComponentComposerLocal() {
      this.openComponentComposer(this.componentId);
    },
    afterComposerPosted() {
      this.fetch();
    },
  },
};
</script>
