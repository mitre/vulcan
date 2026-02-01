<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <ControlsPageLayout
      :has-selected-rule="!!selectedRule"
      :show-command-bar="true"
      :sidebar-width="2"
      empty-state-message="Select a control on the left to view."
    >
      <!-- Command Bar -->
      <template #command-bar>
        <ComponentCommandBar
          :component="component"
          :selected-rule="selectedRule"
          :effective-permissions="effective_permissions"
          :active-panel="activePanel"
          @release="confirmComponentRelease"
          @toggle-advanced-fields="toggleAdvancedFields"
          @open-members="$bvModal.show('members-modal')"
          @toggle-panel="togglePanel"
        />
      </template>

      <!-- Left Sidebar -->
      <template #left-sidebar>
        <RuleNavigator
          :component-id="component.id"
          :rules="rules"
          :selected-rule-id="selectedRuleId"
          :effective-permissions="effective_permissions"
          :project-prefix="component.prefix"
          :read-only="true"
          :open-rule-ids="openRuleIds"
          @ruleSelected="handleRuleSelected"
          @ruleDeselected="handleRuleDeselected"
        />
      </template>

      <!-- Main Content -->
      <template #main-content>
        <template v-if="selectedRule">
          <RuleEditor
            :rule="selectedRule"
            :statuses="statuses"
            :severities="severities"
            :severities_map="severities_map"
            :read-only="true"
            :advanced_fields="component.advanced_fields"
            :additional_questions="component.additional_questions"
          />
        </template>
      </template>

      <!-- Modals -->
      <template #modals>
        <!-- Members Modal -->
        <MembersModal
          :component="component"
          :effective-permissions="effective_permissions"
          :available-roles="available_roles"
        />

        <!-- Related Rules Modal -->
        <RelatedRulesModal
          v-if="selectedRule"
          :read-only="true"
          :rule="selectedRule"
          :rule-stig-id="`${component.prefix}-${selectedRule.rule_id}`"
        />
      </template>

      <!-- Right Panels (Slideovers) -->
      <template #right-panels>
        <!-- Component Details -->
        <b-sidebar
          id="sidebar-details"
          title="Component Details"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'details'"
          @hidden="closePanel"
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
              <p class="mb-2"><strong>PoC Name:</strong> {{ component.admin_name || 'Not set' }}</p>
            </div>
            <div>
              <p class="mb-2"><strong>PoC Email:</strong> {{ component.admin_email || 'Not set' }}</p>
            </div>
            <UpdateComponentDetailsModal
              v-if="role_gte_to(effective_permissions, 'admin')"
              :component="component"
              @componentUpdated="refreshComponent"
            />
          </div>
        </b-sidebar>

        <!-- Component Metadata -->
        <b-sidebar
          id="sidebar-metadata"
          title="Component Metadata"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'metadata'"
          @hidden="closePanel"
        >
          <div class="px-3 py-2">
            <small
              v-if="
                role_gte_to(effective_permissions, 'admin') &&
                (!component.metadata || !component.metadata.hasOwnProperty('Slack Channel ID'))
              "
              class="text-muted d-block mb-3"
            >
              For Slack notifications, add metadata with key "Slack Channel ID".
            </small>
            <div v-for="(value, propertyName) in component.metadata" :key="propertyName">
              <p class="mb-2"><strong>{{ propertyName }}:</strong> {{ value }}</p>
            </div>
            <div v-if="!component.metadata || Object.keys(component.metadata).length === 0">
              <p class="text-muted">No metadata defined.</p>
            </div>
            <UpdateMetadataModal
              v-if="role_gte_to(effective_permissions, 'author')"
              :component="component"
              @componentUpdated="refreshComponent"
            />
          </div>
        </b-sidebar>

        <!-- Component Additional Questions -->
        <b-sidebar
          id="sidebar-questions"
          title="Additional Questions"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'questions'"
          @hidden="closePanel"
        >
          <div class="px-3 py-2">
            <div
              v-for="question in component.additional_questions"
              :key="question.id + question.question_type + question.name"
            >
              <p class="mb-2">
                <strong>{{ question.name }}:</strong>
                <template v-if="question.question_type === 'dropdown'">
                  Options: {{ question.options.join(', ') }}
                </template>
                <template v-else-if="question.question_type === 'url'">URL</template>
                <template v-else>Freeform Text</template>
              </p>
            </div>
            <div v-if="!component.additional_questions || component.additional_questions.length === 0">
              <p class="text-muted">No additional questions defined.</p>
            </div>
            <AddQuestionsModal
              v-if="role_gte_to(effective_permissions, 'author')"
              :component="component"
              @componentUpdated="refreshComponent"
            />
          </div>
        </b-sidebar>

        <!-- Component History -->
        <b-sidebar
          id="sidebar-comp-history"
          title="Component History"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'comp-history'"
          @hidden="closePanel"
        >
          <div class="px-3 py-2">
            <History
              :histories="component.histories"
              :revertable="false"
              abbreviate-type="BaseRule"
            />
          </div>
        </b-sidebar>

        <!-- Component Reviews -->
        <b-sidebar
          id="sidebar-comp-reviews"
          title="Component Reviews"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'comp-reviews'"
          @hidden="closePanel"
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
          title="Also Satisfies"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'satisfies'"
          @hidden="closePanel"
        >
          <div v-if="selectedRule" class="px-3 py-2">
            <RuleSatisfactions
              :component="component"
              :rule="selectedRule"
              :selected-rule-id="selectedRuleId"
              :project-prefix="component.prefix"
              :read-only="true"
              @ruleSelected="handleRuleSelected"
            />
          </div>
        </b-sidebar>

        <!-- Rule Reviews -->
        <b-sidebar
          id="sidebar-reviews"
          title="Rule Reviews"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'reviews'"
          @hidden="closePanel"
        >
          <div v-if="selectedRule" class="px-3 py-2">
            <RuleReviews :rule="selectedRule" />
          </div>
        </b-sidebar>

        <!-- Rule History -->
        <b-sidebar
          id="sidebar-history"
          title="Rule History"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'history'"
          @hidden="closePanel"
        >
          <div v-if="selectedRule" class="px-3 py-2">
            <RuleHistories
              :rule="selectedRule"
              :component="component"
              :statuses="statuses"
              :severities="severities"
            />
          </div>
        </b-sidebar>
      </template>
    </ControlsPageLayout>
  </div>
</template>

<script>
import { toRef } from "vue";
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import SortRulesMixin from "../../mixins/SortRulesMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import { useRuleSelection, useSidebar } from "../../composables";
import ControlsPageLayout from "../rules/ControlsPageLayout.vue";
import ComponentCommandBar from "./ComponentCommandBar.vue";
import RuleNavigator from "../rules/RuleNavigator.vue";
import RuleEditor from "../rules/RuleEditor.vue";
import RuleSatisfactions from "../rules/RuleSatisfactions.vue";
import RuleReviews from "../rules/RuleReviews.vue";
import RuleHistories from "../rules/RuleHistories.vue";
import RelatedRulesModal from "../rules/RelatedRulesModal.vue";
import History from "../shared/History.vue";
import MembersModal from "./MembersModal.vue";
import UpdateComponentDetailsModal from "./UpdateComponentDetailsModal.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import AddQuestionsModal from "./AddQuestionsModal.vue";

export default {
  name: "ProjectComponent",
  components: {
    ControlsPageLayout,
    ComponentCommandBar,
    RuleNavigator,
    RuleEditor,
    RuleSatisfactions,
    RuleReviews,
    RuleHistories,
    RelatedRulesModal,
    History,
    MembersModal,
    UpdateComponentDetailsModal,
    UpdateMetadataModal,
    AddQuestionsModal,
  },
  mixins: [
    DateFormatMixinVue,
    AlertMixinVue,
    RoleComparisonMixin,
    ConfirmComponentReleaseMixin,
    SortRulesMixin,
  ],
  props: {
    queriedRule: {
      type: Object,
      default() {
        return {};
      },
    },
    effective_permissions: {
      type: String,
    },
    initialComponentState: {
      type: Object,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    current_user_id: {
      type: Number,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
    severities_map: {
      type: Object,
      required: true,
    },
    available_roles: {
      type: Array,
      required: true,
    },
  },
  setup(props) {
    // Create reactive reference to rules from component
    const component = props.initialComponentState;
    const rulesRef = toRef(component, "rules");
    const componentId = component.id;

    // Use composables
    const {
      selectedRuleId,
      openRuleIds,
      selectedRule,
      selectRule,
      deselectRule,
    } = useRuleSelection(rulesRef, componentId);

    const { activePanel, togglePanel, closePanel } = useSidebar();

    // Backward compatibility aliases
    const handleRuleSelected = selectRule;
    const handleRuleDeselected = deselectRule;

    return {
      selectedRuleId,
      openRuleIds,
      selectedRule,
      selectRule,
      deselectRule,
      handleRuleSelected,
      handleRuleDeselected,
      activePanel,
      togglePanel,
      closePanel,
    };
  },
  data() {
    return {
      component: this.initialComponentState,
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
    rules() {
      return [...this.component.rules].sort(this.compareRules);
    },
    breadcrumbs() {
      return [
        {
          text: "Projects",
          href: "/projects",
        },
        {
          text: this.project.name,
          href: `/projects/${this.project.id}`,
        },
        {
          text: this.component.name,
          active: true,
        },
      ];
    },
    componentPanels() {
      return ["details", "metadata", "questions", "comp-history", "comp-reviews"];
    },
    rulePanels() {
      return ["satisfies", "reviews", "history"];
    },
  },
  mounted() {
    // Handle deep linking to specific rule
    if (this.queriedRule && this.queriedRule.id) {
      this.selectRule(this.queriedRule.id);
      window.history.pushState({}, "", `/components/${this.component.id}`);
    }
  },
  methods: {
    refreshComponent() {
      axios.get(`/components/${this.component.id}`).then((response) => {
        this.component = response.data;
        location.reload();
      });
    },
    toggleAdvancedFields(advanced_fields) {
      if (
        confirm(
          `Are you sure you want to ${advanced_fields ? "enable" : "disable"} advanced fields?`
        )
      ) {
        const payload = {
          component: {
            advanced_fields: advanced_fields,
          },
        };
        axios
          .patch(`/components/${this.component.id}`, payload)
          .then(this.alertOrNotifyResponse)
          .catch(this.alertOrNotifyResponse);
      }
    },
  },
};
</script>

<style scoped>
.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>
