<template>
  <div>
    <div class="mb-2 d-flex align-items-center">
      <strong>Reviews &amp; Comments</strong>
      <b-badge pill variant="info" class="ml-1">{{ rule.reviews.length }}</b-badge>
      <FilterDropdown
        v-if="topLevelComments.length > 0"
        v-model="sectionFilter"
        :options="sectionFilterOptions"
        aria-label="Filter by section"
        class="ml-auto"
      />
    </div>
    <p v-if="triageHref" class="mb-2 small">
      <a :href="triageHref" data-turbolinks="false">
        <b-icon icon="kanban" class="mr-1" /> Open triage queue for this component
      </a>
    </p>

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
      <p class="mb-1 white-space-pre-wrap">{{ parent.comment }}</p>

      <CommentThread
        v-if="parent.action === 'comment'"
        :ref="`thread-${parent.id}`"
        :parent-review-id="parent.id"
        :responses-count="responsesCountFor(parent.id)"
        :can-reply="canReply"
        :initially-expanded="responsesCountFor(parent.id) > 0"
        @reply="onReply"
      />
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
import FilterDropdown from "../shared/FilterDropdown.vue";
import CommentThread from "../shared/CommentThread.vue";

export default {
  name: "RuleReviews",
  components: { SectionLabel, TriageStatusBadge, FilterDropdown, CommentThread },
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
    commentsClosed: {
      type: Boolean,
      default: false,
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
    // Authenticated viewer+ can reply during an open comment window.
    // Server enforces via reject_if_comments_closed + authorize_viewer_project.
    canReply() {
      return !!this.currentUserId && !!this.effectivePermissions && !this.commentsClosed;
    },
    triageHref() {
      const componentId = this.rule?.component_id;
      return componentId ? `/components/${componentId}/triage` : null;
    },
  },
  methods: {
    // Count replies known locally on rule.reviews. CommentThread also fetches
    // the canonical list via /reviews/:id/responses on expand; this count
    // drives the toggle visibility before the fetch resolves.
    responsesCountFor(parentId) {
      return (this.rule.reviews || []).filter((r) => r.responding_to_review_id === parentId).length;
    },
    onReply(parentId) {
      this.$emit("open-reply-composer", parentId);
    },
  },
};
</script>

<style scoped></style>
