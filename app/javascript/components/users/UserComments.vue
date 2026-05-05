<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <h5 class="mb-0"><b-icon icon="chat-left-text" class="mr-1" /> My Comments</h5>
    </b-card-header>
    <b-card-body>
      <!-- Filter row uses the shared FilterDropdown so the menu stays in
           the visible window even near viewport edges (native <select>
           dropdowns ignore Vue boundary props). -->
      <div class="d-flex align-items-center mb-3" style="gap: 0.5rem">
        <FilterDropdown
          v-model="filterStatus"
          :options="statusOptions"
          aria-label="Filter by status"
          @input="onFilterChanged"
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
      </div>

      <b-table
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
        aria-label="My comments"
      >
        <template #cell(rule_displayed_name)="{ item }">
          <!-- data-turbolinks="false" forces a full page load so the rule
               editor's project_component pack registers its turbolinks:load
               listener before the event fires (otherwise Vue never mounts
               and the rule editor is blank). -->
          <a :href="ruleHref(item)" data-turbolinks="false">{{ item.rule_displayed_name }}</a>
        </template>
        <template #cell(component_name)="{ item }">
          <a :href="`/components/${item.component_id}`" data-turbolinks="false">
            {{ item.component_name }}
          </a>
          <small class="text-muted d-block">{{ item.project_name }}</small>
        </template>
        <template #cell(section)="{ value }">
          <SectionLabel :section="value" />
        </template>
        <template #cell(comment)="{ item, value }">
          <div :title="value">{{ truncate(value, 80) }}</div>
          <CommentThread
            :ref="`thread-${item.id}`"
            :parent-review-id="item.id"
            :responses-count="item.responses_count || 0"
            :can-reply="true"
            class="mt-1"
            @reply="openReplyComposer(item)"
          />
        </template>
        <template #cell(created_at)="{ value }">
          {{ friendlyDateTime(value) }}
        </template>
        <template #cell(triage_status)="{ item }">
          <TriageStatusBadge :status="item.triage_status" :adjudicated-at="item.adjudicated_at" />
        </template>
        <template #cell(latest_activity_at)="{ value }">
          <span v-if="value">{{ friendlyDateTime(value) }}</span>
          <span v-else class="text-muted">—</span>
        </template>
        <template #table-busy>
          <div class="text-center py-3"><b-spinner small /> Loading…</div>
        </template>
        <template #empty>
          <div class="text-center py-5">
            <b-icon icon="chat-left-text" class="text-muted mb-2" font-scale="2" />
            <h6 class="mb-2">You have no comments yet</h6>
            <p class="text-muted mb-0">
              Add a comment on a component and you'll be able to track its triage status here.
            </p>
          </div>
        </template>
      </b-table>

      <div v-if="total > perPage" class="d-flex justify-content-center my-2">
        <b-pagination
          v-model="page"
          :total-rows="total"
          :per-page="perPage"
          aria-label="Pagination"
          @input="fetch"
        />
      </div>

      <!-- Reply composer. Bindings derive from the row whose CommentThread
           emitted reply. componentId/ruleId/ruleDisplayedName come from
           the row payload (carried in /users/:id/comments). -->
      <CommentComposerModal
        v-if="composerReplyRow"
        :component-id="composerReplyRow.component_id"
        :rule-id="composerReplyRow.rule_id"
        :rule-displayed-name="composerReplyRow.rule_displayed_name"
        :reply-to-review-id="composerReplyRow.id"
        @posted="onComposerPosted"
        @hidden="onComposerHidden"
      />
    </b-card-body>
  </b-card>
</template>

<script>
import axios from "axios";
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";
import AlertMixin from "../../mixins/AlertMixin.vue";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";
import FilterDropdown from "../shared/FilterDropdown.vue";
import CommentThread from "../shared/CommentThread.vue";
import CommentComposerModal from "../components/CommentComposerModal.vue";

export default {
  name: "UserComments",
  components: {
    TriageStatusBadge,
    SectionLabel,
    FilterDropdown,
    CommentThread,
    CommentComposerModal,
  },
  mixins: [AlertMixin, DateFormatMixin],
  props: {
    userId: { type: [Number, String], required: true },
  },
  data() {
    return {
      rows: [],
      total: 0,
      page: 1,
      perPage: 25,
      loading: false,
      filterStatus: "all",
      // .sync-bound to b-table so the active sort-direction arrow renders
      // when the user clicks a column header.
      sortBy: "created_at",
      sortDesc: true,
      composerReplyRow: null,
      fields: [
        { key: "rule_displayed_name", label: "Rule", sortable: true },
        { key: "component_name", label: "Component / Project", sortable: true },
        { key: "section", label: "Section", sortable: true },
        { key: "comment", label: "Comment", sortable: false },
        { key: "created_at", label: "Posted", sortable: true },
        { key: "triage_status", label: "Status", sortable: true },
        { key: "latest_activity_at", label: "Last activity", sortable: true },
      ],
    };
  },
  computed: {
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
  },
  mounted() {
    this.fetch();
  },
  methods: {
    truncate(text, n) {
      if (!text) return "";
      return text.length > n ? `${text.slice(0, n)}…` : text;
    },
    // Deep link to the rule editor with the rule selected. Encode the
    // rule name segment so unusual characters can't break out of the
    // path (mirrors ComponentComments#ruleHref).
    ruleHref(row) {
      return `/components/${row.component_id}/${encodeURIComponent(row.rule_displayed_name)}`;
    },
    onFilterChanged() {
      this.page = 1;
      this.fetch();
    },
    openReplyComposer(row) {
      this.composerReplyRow = row;
      this.$nextTick(() => this.$bvModal.show("comment-composer-modal"));
    },
    onComposerPosted() {
      const id = this.composerReplyRow?.id;
      this.composerReplyRow = null;
      this.fetch();
      if (id) {
        this.$nextTick(() => {
          const ref = this.$refs[`thread-${id}`];
          const thread = Array.isArray(ref) ? ref[0] : ref;
          thread?.refresh?.();
        });
      }
    },
    onComposerHidden() {
      this.composerReplyRow = null;
    },
    async fetch() {
      this.loading = true;
      try {
        const params = { page: this.page, per_page: this.perPage };
        if (this.filterStatus && this.filterStatus !== "all") {
          params.triage_status = this.filterStatus;
        }
        // Explicit Accept header — the user_comments pack has its own
        // axios singleton (esbuild bundle isolation) and doesn't pull in
        // FormMixin's defaults setup, so without this Rails serves the
        // HTML view of the same /users/:id/comments route.
        const { data } = await axios.get(`/users/${this.userId}/comments`, {
          params,
          headers: { Accept: "application/json" },
        });
        this.rows = data.rows;
        this.total = data.pagination.total;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.loading = false;
      }
    },
  },
};
</script>
