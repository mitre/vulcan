<template>
  <div>
    <!-- Component Details -->
    <b-sidebar
      id="sidebar-details"
      :title="titles.details"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'details'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <div v-if="component.name">
          <p class="mb-2"><strong>Name:</strong> {{ component.name }}</p>
        </div>
        <div v-if="component.version">
          <p class="mb-2"><strong>Version:</strong> {{ component.version }}</p>
        </div>
        <div v-if="component.release">
          <p class="mb-2"><strong>Release:</strong> {{ component.release }}</p>
        </div>
        <div v-if="component.title">
          <p class="mb-2"><strong>Title:</strong> {{ component.title }}</p>
        </div>
        <div v-if="component.description">
          <p class="mb-2"><strong>Description:</strong> {{ component.description }}</p>
        </div>
        <div>
          <p class="mb-2"><strong>PoC Name:</strong> {{ component.admin_name || "Not set" }}</p>
        </div>
        <div>
          <p class="mb-2"><strong>PoC Email:</strong> {{ component.admin_email || "Not set" }}</p>
        </div>
        <UpdateComponentDetailsModal
          v-if="canAdmin"
          :component="component"
          @componentUpdated="$emit('component-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Component Metadata -->
    <b-sidebar
      id="sidebar-metadata"
      :title="titles.metadata"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'metadata'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <small
          v-if="
            canAdmin &&
            (!component.metadata || !component.metadata.hasOwnProperty('Slack Channel ID'))
          "
          class="text-muted d-block mb-3"
        >
          For Slack notifications, add metadata with key "Slack Channel ID".
        </small>
        <div v-for="(value, propertyName) in component.metadata" :key="propertyName">
          <p class="mb-2">
            <strong>{{ propertyName }}:</strong> {{ value }}
          </p>
        </div>
        <div v-if="!component.metadata || Object.keys(component.metadata).length === 0">
          <p class="text-muted">No metadata defined.</p>
        </div>
        <UpdateMetadataModal
          v-if="canAuthor"
          :component="component"
          @componentUpdated="$emit('component-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Component Additional Questions -->
    <b-sidebar
      id="sidebar-questions"
      :title="titles.questions"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'questions'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <div
          v-for="question in component.additional_questions"
          :key="question.id + question.question_type + question.name"
        >
          <p class="mb-2">
            <strong>{{ question.name }}:</strong>
            <template v-if="question.question_type === 'dropdown'">
              Options: {{ question.options.join(", ") }}
            </template>
            <template v-else-if="question.question_type === 'url'">URL</template>
            <template v-else>Freeform Text</template>
          </p>
        </div>
        <div v-if="!component.additional_questions || component.additional_questions.length === 0">
          <p class="text-muted">No additional questions defined.</p>
        </div>
        <AddQuestionsModal
          v-if="canAuthor"
          :component="component"
          @componentUpdated="$emit('component-updated')"
        />
      </div>
    </b-sidebar>

    <!-- Component History -->
    <b-sidebar
      id="sidebar-comp-history"
      :title="titles.compHistory"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'comp-history'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <History :histories="displayedHistories" :revertable="false" abbreviate-type="BaseRule" />
      </div>
    </b-sidebar>

    <!-- Component Reviews -->
    <b-sidebar
      id="sidebar-comp-reviews"
      :title="titles.compReviews"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'comp-reviews'"
      @hidden="$emit('close-panel')"
    >
      <div class="px-3 py-2">
        <div v-for="review in component.reviews" :key="review.id">
          <p class="mb-1">
            <strong>{{ review.displayed_rule_name }}</strong>
          </p>
          <p class="mb-1">
            <strong>{{ review.name }} - {{ actionDescriptions[review.action] }}</strong>
          </p>
          <p class="mb-1">
            <small class="text-muted">{{ friendlyDateTime(review.created_at) }}</small>
          </p>
          <p class="mb-3 white-space-pre-wrap">{{ review.comment }}</p>
        </div>
        <div v-if="!component.reviews || component.reviews.length === 0">
          <p class="text-muted">No reviews yet.</p>
        </div>
      </div>
    </b-sidebar>

    <!-- Rule Satisfies -->
    <b-sidebar
      id="sidebar-satisfies"
      :title="titles.satisfies"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'satisfies'"
      @hidden="$emit('close-panel')"
    >
      <div v-if="selectedRule" class="px-3 py-2">
        <RuleSatisfactions
          :component="component"
          :rule="selectedRule"
          :selected-rule-id="selectedRuleId"
          :project-prefix="component.prefix"
          :read-only="readOnly"
          @ruleSelected="$emit('rule-selected', $event)"
        />
      </div>
    </b-sidebar>

    <!-- Rule Reviews -->
    <b-sidebar
      id="sidebar-rule-reviews"
      :title="titles.ruleReviews"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'rule-reviews'"
      @hidden="$emit('close-panel')"
    >
      <div v-if="selectedRule" class="px-3 py-2">
        <RuleReviews
          :rule="selectedRule"
          :effective-permissions="effectivePermissions"
          :current-user-id="currentUserId"
        />
      </div>
    </b-sidebar>

    <!-- Rule History -->
    <b-sidebar
      id="sidebar-rule-history"
      :title="titles.ruleHistory"
      right
      shadow
      backdrop
      width="400px"
      :visible="activePanel === 'rule-history'"
      @hidden="$emit('close-panel')"
    >
      <div v-if="selectedRule" class="px-3 py-2">
        <RuleHistories :rule="selectedRule" :component="component" :statuses="statuses" />
      </div>
    </b-sidebar>
  </div>
</template>

<script>
import axios from "axios";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import { SIDEBAR_TITLES } from "../../constants/terminology";
import History from "./History.vue";
import RuleSatisfactions from "../rules/RuleSatisfactions.vue";
import RuleReviews from "../rules/RuleReviews.vue";
import RuleHistories from "../rules/RuleHistories.vue";
import UpdateComponentDetailsModal from "../components/UpdateComponentDetailsModal.vue";
import UpdateMetadataModal from "../components/UpdateMetadataModal.vue";
import AddQuestionsModal from "../components/AddQuestionsModal.vue";

export default {
  name: "ControlsSidepanels",
  components: {
    History,
    RuleSatisfactions,
    RuleReviews,
    RuleHistories,
    UpdateComponentDetailsModal,
    UpdateMetadataModal,
    AddQuestionsModal,
  },
  mixins: [RoleComparisonMixin, DateFormatMixinVue],
  props: {
    component: {
      type: Object,
      required: true,
    },
    selectedRule: {
      type: Object,
      default: null,
    },
    selectedRuleId: {
      type: [Number, String],
      default: null,
    },
    activePanel: {
      type: String,
      default: null,
    },
    effectivePermissions: {
      type: String,
      required: true,
    },
    currentUserId: {
      type: Number,
      default: null,
    },
    statuses: {
      type: Array,
      default: () => [],
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  data() {
    return {
      titles: SIDEBAR_TITLES,
      localHistories: [],
      actionDescriptions: {
        comment: "Commented",
        request_review: "Requested Review",
        revoke_review_request: "Revoked Request for Review",
        request_changes: "Requested Changes",
        approve: "Approved",
        lock_control: "Locked",
        unlock_control: "Unlocked",
      },
    };
  },
  computed: {
    canAdmin() {
      return this.role_gte_to(this.effectivePermissions, "admin");
    },
    canAuthor() {
      return this.role_gte_to(this.effectivePermissions, "author");
    },
    // Use local histories if available (refreshed via event), otherwise fall back to prop
    displayedHistories() {
      return this.localHistories.length > 0 ? this.localHistories : this.component.histories;
    },
  },
  mounted() {
    this.$root.$on("refresh:activity", this.refreshHistories);
  },
  beforeDestroy() {
    this.$root.$off("refresh:activity", this.refreshHistories);
  },
  methods: {
    refreshHistories() {
      axios
        .get(`/components/${this.component.id}/histories`)
        .then((response) => {
          this.localHistories = response.data;
        })
        .catch(() => {}); // Silently fail — non-critical UI refresh
    },
  },
};
</script>

<style scoped>
.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>
