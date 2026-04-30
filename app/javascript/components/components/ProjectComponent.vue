<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <CommentPeriodBanner :component="component" @open-comments-panel="openCommentsPanel" />

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
          @open-members="$bvModal.show(`members-modal-${component.id}`)"
          @toggle-panel="togglePanel"
          @spreadsheet-updated="refreshComponent"
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
            :read-only="true"
            :effective-permissions="effective_permissions"
            :advanced_fields="localAdvancedFields"
            :additional_questions="component.additional_questions"
            @open-related-modal="$bvModal.show('related-rules-modal')"
            @open-composer="onOpenComposer"
            @toggle-panel="togglePanel"
            @toggle-advanced-fields="toggleAdvancedFields"
          />
        </template>
      </template>

      <!-- Modals -->
      <template #modals>
        <!-- Related Rules Modal -->
        <RelatedRulesModal
          v-if="selectedRule"
          :read-only="true"
          :rule="selectedRule"
          :rule-stig-id="`${component.prefix}-${selectedRule.rule_id}`"
        />

        <!-- Comment composer modal (PR #717). Opens via onOpenComposer
             when a SectionCommentIcon emits open-composer. -->
        <CommentComposerModal
          v-if="selectedRule"
          :component-id="component.id"
          :rule-id="selectedRule.id"
          :rule-displayed-name="`${component.prefix}-${selectedRule.rule_id}`"
          :initial-section="composerSection"
          @posted="onComposerPosted"
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
import { computed } from "vue";
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
import RelatedRulesModal from "../rules/RelatedRulesModal.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import CommentComposerModal from "./CommentComposerModal.vue";
import CommentPeriodBanner from "./CommentPeriodBanner.vue";

export default {
  name: "ProjectComponent",
  components: {
    ControlsPageLayout,
    ControlsCommandBar,
    RuleFilterBar,
    RuleNavigator,
    RuleEditor,
    RelatedRulesModal,
    ControlsSidepanels,
    CommentComposerModal,
    CommentPeriodBanner,
  },
  mixins: [
    DateFormatMixinVue,
    AlertMixinVue,
    RoleComparisonMixin,
    ConfirmComponentReleaseMixin,
    SortRulesMixin,
  ],
  // PR #717 phase enforcement — provide the component's comment_phase
  // (and a derived `commentsClosed` boolean) to the rule-editor subtree
  // so SectionCommentIcon can disable the comment affordance when the
  // window isn't open. Function form keeps reactivity through Vue 2's
  // non-reactive provide.
  provide() {
    return {
      getCommentPhase: () => this.component.comment_phase || "draft",
      isCommentsClosed: () => (this.component.comment_phase || "draft") !== "open",
    };
  },
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
    available_roles: {
      type: Array,
      required: true,
    },
  },
  setup(props) {
    // Use computed to derive rules reactively — toRef on a plain object is not reactive in Vue 2.7
    const componentId = props.initialComponentState.id;
    const rulesRef = computed(() => props.initialComponentState.rules || []);

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
      localAdvancedFields: this.initialComponentState.advanced_fields,
      msg: MESSAGE_LABELS,
      // PR #717: section pre-selected on the comment composer when a
      // SectionCommentIcon click bubbles open-composer up to here.
      composerSection: null,
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
      return ["details", "metadata", "questions", "comp-history"];
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
    /**
     * PR #717 — open the comment composer with a pre-selected section.
     * Triggered when SectionCommentIcon emits open-composer; the event
     * bubbles up RuleFormGroup → form → UnifiedRuleForm → RuleEditor.
     */
    onOpenComposer(section) {
      this.composerSection = section;
      this.$bvModal.show("comment-composer-modal");
    },
    /**
     * PR #717 — refresh the component (and selected rule's reviews) after
     * a comment is posted so the per-section pending-count badge updates.
     */
    onComposerPosted() {
      this.refreshComponent();
    },
    openCommentsPanel() {
      window.location.href = `/components/${this.component.id}/triage`;
    },
    refreshComponent() {
      axios
        .get(`/components/${this.component.id}.json`)
        .then((response) => {
          // Update component properties in-place for Vue reactivity
          Object.assign(this.component, response.data);
        })
        .catch((error) => {
          this.alertOrNotifyResponse(error);
        });
    },
    toggleAdvancedFields(advanced_fields) {
      // Confirmation is now handled in RuleEditor component
      const payload = {
        component: {
          advanced_fields: advanced_fields,
        },
      };
      axios
        .patch(`/components/${this.component.id}`, payload)
        .then((response) => {
          this.alertOrNotifyResponse(response);
          // Update local data property (not prop) for proper reactivity through slots
          this.localAdvancedFields = advanced_fields;
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>
