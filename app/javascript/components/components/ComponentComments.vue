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
        <a href="#" @click.prevent="$emit('jump-to-rule', item.rule_id)">
          {{ item.rule_displayed_name }}
        </a>
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
        <b-button
          v-if="!item.adjudicated_at"
          size="sm"
          variant="outline-primary"
          @click="openTriageFor(item)"
        >
          {{ item.triage_status === "pending" ? "Triage" : "Close" }}
        </b-button>
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
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";
import SectionLabel from "../shared/SectionLabel.vue";
import CommentTriageModal from "./CommentTriageModal.vue";

export default {
  name: "ComponentComments",
  components: { TriageStatusBadge, SectionLabel, CommentTriageModal },
  mixins: [AlertMixin],
  props: {
    componentId: { type: [Number, String], required: true },
  },
  data() {
    return {
      rows: [],
      total: 0,
      page: 1,
      perPage: 25,
      loading: false,
      filterText: "",
      filterStatus: "pending",
      filterSection: null,
      selectedRow: null,
      fields: [
        { key: "id", label: "#", sortable: false },
        { key: "rule_displayed_name", label: "Rule", sortable: true },
        { key: "section", label: "Section", sortable: true },
        { key: "author_name", label: "Author", sortable: true },
        { key: "comment", label: "Comment", sortable: false },
        { key: "created_at", label: "Posted", sortable: true },
        { key: "triage_status", label: "Status", sortable: true },
        { key: "actions", label: "Action", sortable: false },
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
    truncate(text, n) {
      if (!text) return "";
      return text.length > n ? `${text.slice(0, n)}…` : text;
    },
    friendlyDateTime(value) {
      if (!value) return "";
      return new Date(value).toLocaleString();
    },
    onFilterChanged() {
      this.page = 1;
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
        const { data } = await axios.get(`/components/${this.componentId}/comments`, { params });
        this.rows = data.rows;
        this.total = data.pagination.total;
      } catch (error) {
        this.alertOrNotifyResponse(error);
      } finally {
        this.loading = false;
      }
    },
    openTriageFor(row) {
      this.selectedRow = row;
      this.$bvModal.show("comment-triage-modal");
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
