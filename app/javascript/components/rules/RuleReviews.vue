<template>
  <div>
    <div class="mb-2 d-flex align-items-center">
      <strong>Reviews &amp; Comments</strong>
      <b-badge pill variant="info" class="ml-1">{{ rule.reviews.length }}</b-badge>
      <b-form-select
        v-if="topLevelComments.length > 0"
        v-model="sectionFilter"
        :options="sectionFilterOptions"
        size="sm"
        class="ml-auto"
        style="max-width: 180px"
        aria-label="Filter by section"
      />
    </div>

    <div v-for="parent in topLevelFilteredVisible" :key="parent.id" class="mb-3">
      <p class="mb-0 d-flex flex-wrap align-items-center">
        <strong>{{ parent.name }}</strong>
        <small class="text-muted ml-2">{{ actionDescriptions[parent.action] }}</small>
        <SectionLabel
          v-if="parent.action === 'comment'"
          :section="parent.section"
          class="badge badge-light ml-2"
        />
        <TriageStatusBadge
          v-if="parent.triage_status"
          :status="parent.triage_status"
          :adjudicated-at="parent.adjudicated_at"
          :duplicate-of-id="parent.duplicate_of_review_id"
          class="ml-2"
        />
      </p>
      <p class="mb-1">
        <small class="text-muted">{{ friendlyDateTime(parent.created_at) }}</small>
      </p>
      <p class="mb-0 white-space-pre-wrap">{{ parent.comment }}</p>

      <div
        v-for="response in responsesFor(parent.id)"
        :key="response.id"
        class="ml-4 mt-2 pl-3 border-left border-info"
      >
        <p class="mb-0">
          <strong>{{ response.name }}</strong>
          <small class="text-muted ml-2">responding to ↑</small>
        </p>
        <p class="mb-1">
          <small class="text-muted">{{ friendlyDateTime(response.created_at) }}</small>
        </p>
        <p class="mb-0 white-space-pre-wrap">{{ response.comment }}</p>
      </div>
    </div>

    <p v-if="rule.reviews.length === 0" class="text-muted small">No reviews or comments yet.</p>
    <p v-else-if="topLevelFilteredAll.length === 0" class="text-muted small">
      No comments match this filter.
    </p>

    <div v-if="topLevelFilteredAll.length > 2" class="d-flex justify-content-center">
      <b-button
        v-if="numShownReviews < topLevelFilteredAll.length"
        size="sm"
        variant="link"
        @click="numShownReviews += 2"
      >
        Show older...
      </b-button>
      <b-button v-if="numShownReviews > 2" size="sm" variant="link" @click="numShownReviews -= 2">
        Show fewer
      </b-button>
    </div>
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import { ACTION_DESCRIPTIONS } from "../../constants/terminology";
import { SECTION_LABELS } from "../../constants/triageVocabulary";
import SectionLabel from "../shared/SectionLabel.vue";
import TriageStatusBadge from "../shared/TriageStatusBadge.vue";

export default {
  name: "RuleReviews",
  components: { SectionLabel, TriageStatusBadge },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      required: false,
      default: null,
    },
    currentUserId: {
      type: Number,
      required: false,
      default: null,
    },
    rule: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      numShownReviews: 2,
      actionDescriptions: ACTION_DESCRIPTIONS,
      sectionFilter: "all",
    };
  },
  computed: {
    sectionFilterOptions() {
      return [
        { value: "all", text: "All sections" },
        { value: "(general)", text: "(general)" },
        ...Object.entries(SECTION_LABELS).map(([value, text]) => ({ value, text })),
      ];
    },
    // Top-level rows: status-changing actions are always top level, comments
    // are top level only when not responding to a parent.
    topLevelComments() {
      return [...this.rule.reviews]
        .filter((r) => r.action !== "comment" || r.responding_to_review_id == null)
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
    },
    // Filtered by section but NOT yet sliced — drives pagination + empty
    // state. Section filter applies to comments only; status-change actions
    // (e.g. request-review, approve) are always shown.
    topLevelFilteredAll() {
      if (this.sectionFilter === "all") return this.topLevelComments;
      return this.topLevelComments.filter((r) => {
        if (r.action !== "comment") return true;
        if (this.sectionFilter === "(general)") return r.section == null;
        return r.section === this.sectionFilter;
      });
    },
    // What the v-for actually renders: filtered + sliced.
    topLevelFilteredVisible() {
      return this.topLevelFilteredAll.slice(0, this.numShownReviews);
    },
  },
  methods: {
    responsesFor(parentId) {
      return (this.rule.reviews || []).filter((r) => r.responding_to_review_id === parentId);
    },
  },
};
</script>

<style scoped></style>
