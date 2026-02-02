<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <ControlsPageLayout
      :has-selected-rule="!!selectedRule"
      :show-command-bar="true"
      :show-filter-bar="true"
      :sidebar-width="2"
      :empty-state-message="msg.selectRule"
    >
      <!-- Command Bar -->
      <template #command-bar>
        <ControlsCommandBar
          :component="component"
          :selected-rule="selectedRule"
          :effective-permissions="effective_permissions"
          :active-panel="activePanel"
          :read-only="true"
          @release="confirmComponentRelease"
          @toggle-advanced-fields="toggleAdvancedFields"
          @open-members="$bvModal.show('members-modal')"
          @toggle-panel="togglePanel"
        />
      </template>

      <!-- Filter Bar (Review panel disabled in view mode) -->
      <template #filter-bar>
        <RuleFilterBar
          :filters="filters"
          :counts="counts"
          :show-status="true"
          :show-review="true"
          :show-display="true"
          :disabled-review="true"
          @update:filter="updateFilter"
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
          :external-filters="filters"
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
            :effective-permissions="effective_permissions"
            :advanced_fields="component.advanced_fields"
            :additional_questions="component.additional_questions"
            @open-related-modal="$bvModal.show('related-rules-modal')"
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

      <!-- Right Panels (Slideovers) - Using shared component -->
      <template #right-panels>
        <ControlsSidepanels
          :component="component"
          :selected-rule="selectedRule"
          :selected-rule-id="selectedRuleId"
          :active-panel="activePanel"
          :effective-permissions="effective_permissions"
          :current-user-id="current_user_id"
          :statuses="statuses"
          :severities="severities"
          :read-only="true"
          @close-panel="closePanel"
          @component-updated="refreshComponent"
          @rule-selected="handleRuleSelected"
        />
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
import { useRuleSelection, useRuleFilters, useSidebar } from "../../composables";
import { MESSAGE_LABELS } from "../../constants/terminology";
import ControlsPageLayout from "../rules/ControlsPageLayout.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import RuleFilterBar from "../rules/RuleFilterBar.vue";
import RuleNavigator from "../rules/RuleNavigator.vue";
import RuleEditor from "../rules/RuleEditor.vue";
import RuleSatisfactions from "../rules/RuleSatisfactions.vue";
import RuleReviews from "../rules/RuleReviews.vue";
import RuleHistories from "../rules/RuleHistories.vue";
import RelatedRulesModal from "../rules/RelatedRulesModal.vue";
import History from "../shared/History.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import MembersModal from "./MembersModal.vue";
import UpdateComponentDetailsModal from "./UpdateComponentDetailsModal.vue";
import UpdateMetadataModal from "./UpdateMetadataModal.vue";
import AddQuestionsModal from "./AddQuestionsModal.vue";

export default {
  name: "ProjectComponent",
  components: {
    ControlsPageLayout,
    ControlsCommandBar,
    RuleFilterBar,
    RuleNavigator,
    RuleEditor,
    RuleSatisfactions,
    RuleReviews,
    RuleHistories,
    RelatedRulesModal,
    History,
    ControlsSidepanels,
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
    const { selectedRuleId, openRuleIds, selectedRule, selectRule, deselectRule } =
      useRuleSelection(rulesRef, componentId, { autoSelectFirst: true });

    const { filters, counts, setFilter } = useRuleFilters(rulesRef, componentId);

    const { activePanel, togglePanel, closePanel } = useSidebar();

    // Backward compatibility aliases
    const handleRuleSelected = selectRule;
    const handleRuleDeselected = deselectRule;

    // Filter update with localStorage persistence
    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    };

    return {
      selectedRuleId,
      openRuleIds,
      selectedRule,
      selectRule,
      deselectRule,
      handleRuleSelected,
      handleRuleDeselected,
      filters,
      counts,
      updateFilter,
      activePanel,
      togglePanel,
      closePanel,
    };
  },
  data() {
    return {
      component: this.initialComponentState,
      msg: MESSAGE_LABELS,
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
      // Build component name with version (e.g., "Test 2 V1R1")
      let componentText = this.component.name;
      if (this.component.version || this.component.release) {
        componentText += " ";
        if (this.component.version) componentText += `V${this.component.version}`;
        if (this.component.release) componentText += `R${this.component.release}`;
      }
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
          text: componentText,
          active: true,
        },
      ];
    },
    componentPanels() {
      return ["details", "metadata", "questions", "comp-history", "comp-reviews"];
    },
    rulePanels() {
      return ["satisfies", "rule-reviews", "rule-history"];
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
      axios
        .get(`/components/${this.component.id}.json`)
        .then((response) => {
          // Update component properties in-place for Vue reactivity
          Object.assign(this.component, response.data);
        })
        .catch((error) => {
          console.error("Failed to refresh component:", error);
        });
    },
    toggleAdvancedFields(advanced_fields) {
      if (
        confirm(
          `Are you sure you want to ${advanced_fields ? "enable" : "disable"} advanced fields?`,
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
