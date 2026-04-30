<template>
  <b-card class="mt-3" no-body>
    <b-card-header>
      <h5 class="mb-0"><b-icon icon="chat-left-text" class="mr-1" /> My Comments</h5>
    </b-card-header>

    <!-- Filter row — left-aligned so the native <select> dropdown opens
         well inside the viewport (placing it on the right edge of the
         card-header pushes the dropdown off-screen on wide windows). -->
    <div class="px-3 pt-3 pb-2">
      <b-input-group size="sm" style="max-width: 320px">
        <b-form-select
          v-model="filterStatus"
          :options="statusOptions"
          aria-label="Filter by triage status"
          @change="onFilterChanged"
        />
        <b-button
          v-b-tooltip.hover
          variant="outline-secondary"
          aria-label="Refresh"
          title="Refresh"
          @click="fetch"
        >
          <b-icon icon="arrow-clockwise" />
        </b-button>
      </b-input-group>
    </div>

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
      aria-label="My comments"
    >
      <template #cell(rule_displayed_name)="{ item }">
        <a :href="ruleHref(item)">{{ item.rule_displayed_name }}</a>
      </template>
      <template #cell(component_name)="{ item }">
        <a :href="`/components/${item.component_id}`">{{ item.component_name }}</a>
        <small class="text-muted d-block">{{ item.project_name }}</small>
      </template>
      <template #cell(section)="{ value }">
        <SectionLabel :section="value" />
      </template>
      <template #cell(comment)="{ value }">
        <span :title="value">{{ truncate(value, 80) }}</span>
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
  </b-card>
</template>

<script>
import axios from "axios";
import { TRIAGE_LABELS } from "../../constants/triageVocabulary";
import AlertMixin from "../../mixins/AlertMixin.vue";
import DateFormatMixin from "../../mixins/DateFormatMixin.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";

export default {
  name: "UserComments",
  components: { TriageStatusBadge, SectionLabel },
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
    async fetch() {
      this.loading = true;
      try {
        const params = { page: this.page, per_page: this.perPage };
        if (this.filterStatus && this.filterStatus !== "all") {
          params.triage_status = this.filterStatus;
        }
        const { data } = await axios.get(`/users/${this.userId}/comments`, { params });
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
