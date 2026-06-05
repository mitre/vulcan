<template>
  <div>
    <b-breadcrumb :items="breadcrumbs" />

    <CommentPeriodBanner
      :component="component"
      @open-comments-panel="openCommentsPanel"
      @open-component-composer="onOpenComponentComposer"
    />

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
          @download="openExportModal"
          @open-component-composer="onOpenComponentComposer"
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
          :effective-permissions="effective_permissions"
          :project-prefix="component.prefix"
          :read-only="true"
          :external-filters="filters"
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
            @view-comments="onViewComments"
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

        <CommentComposerModal
          v-if="composerActive"
          v-bind="composerProps"
          :component-displayed-name="component.name"
          @posted="onComposerPosted"
          @hidden="onComposerHidden"
        />

        <!-- Purpose + Format radios.
             Disposition matrix piggybacks into the Working Copy CSV/Excel
             outputs when comments exist (Steps 3+4). -->
        <ExportModal
          v-model="showExportModal"
          :components="[component]"
          :available-modes="availableExportModes"
          :hide-component-selection="true"
          @export="executeExport"
          @cancel="showExportModal = false"
        />
      </template>

      <!-- Right Panels (Slideovers) - Using shared component -->
      <template #right-panels>
        <ControlsSidepanels
          :component="component"
          :selected-rule="selectedRule"
          :active-panel="activePanel"
          :effective-permissions="effective_permissions"
          :current-user-id="current_user_id"
          :statuses="statuses"
          :read-only="true"
          :reviews-section-filter="reviewsSectionFilter"
          @close-panel="closePanel"
          @component-updated="refreshComponent"
          @open-reply-composer="onOpenReplyComposer"
        />
      </template>
    </ControlsPageLayout>
  </div>
</template>

<script>
import { ref, computed } from "vue";
import { getComponent, patchComponent } from "../../api/componentsApi";
import { getRule } from "../../api/rulesApi";
import { exportProjectData } from "../../api/projectsApi";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import SortRulesMixin from "../../mixins/SortRulesMixin.vue";
import ConfirmComponentReleaseMixin from "../../mixins/ConfirmComponentReleaseMixin.vue";
import { useRuleFilters, useSidebar } from "../../composables";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { getFirstVisibleRule } from "../../utils/ruleSelectionUtils";
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
import ExportModal from "../shared/ExportModal.vue";
import ReplyComposerMixin from "../../mixins/ReplyComposerMixin.vue";

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
    ExportModal,
  },
  mixins: [
    DateFormatMixinVue,
    AlertMixinVue,
    RoleComparisonMixin,
    ConfirmComponentReleaseMixin,
    SortRulesMixin,
    ReplyComposerMixin,
  ],
  // Provide the component's comment_phase (and a derived `commentsClosed`
  // boolean) to the rule-editor subtree so SectionCommentIcon can disable
  // the comment affordance when the window isn't open. Function form
  // keeps reactivity through Vue 2's non-reactive provide.
  provide() {
    return {
      getCommentPhase: () => this.component.comment_phase || "open",
      getClosedReason: () => this.component.closed_reason || null,
      isCommentsClosed: () => (this.component.comment_phase || "open") !== "open",
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
    const componentId = props.initialComponentState.id;
    const localRules = ref(structuredClone(props.initialComponentState.rules || []));

    const ruleStore = useRuleSelectionStore();

    const selectedRuleId = computed(() => ruleStore.selectedRuleId);
    const openRuleIds = computed(() => ruleStore.openRuleIds);
    const selectedRule = computed(() => {
      if (ruleStore.selectedRuleId === null) return null;
      return localRules.value.find((r) => r.id === ruleStore.selectedRuleId) || null;
    });

    const selectRule = (ruleId) => ruleStore.selectRule(ruleId);
    const deselectRule = (ruleId) => ruleStore.deselectRule(ruleId);
    const handleRuleSelected = selectRule;
    const handleRuleDeselected = deselectRule;

    const { filters, counts, setFilter } = useRuleFilters(localRules, componentId);
    const { activePanel, togglePanel, closePanel } = useSidebar();

    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    };

    return {
      ruleStore,
      localRules,
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
      // per-component editor Download surface.
      // Mode-aware ExportModal (Working Copy / Vendor Submission /
      // STIG-Ready Publish Draft / Backup) hits the project export
      // route scoped to this single component.
      showExportModal: false,
      availableExportModes: ["working_copy", "vendor_submission", "published_stig", "backup"],
      reviewsSectionFilter: "all",
    };
  },
  computed: {
    rules() {
      return [...this.localRules].sort(this.compareRules);
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
    this.ruleStore.init(this.$router, this.component.id);

    if (this.queriedRule && this.queriedRule.id) {
      this.ruleStore.selectRule(this.queriedRule.id);
    } else if (this.ruleStore.selectedRuleId === null && this.localRules.length > 0) {
      const firstVisible = getFirstVisibleRule(this.localRules);
      if (firstVisible) this.ruleStore.selectRule(firstVisible.id);
    }
  },
  methods: {
    /**
     * open the comment composer with a pre-selected section.
     * Triggered when SectionCommentIcon emits open-composer; the event
     * bubbles up RuleFormGroup → form → UnifiedRuleForm → RuleEditor.
     */
    onViewComments(section) {
      this.reviewsSectionFilter = section || "all";
      this.togglePanel("rule-reviews");
    },
    onOpenComposer(section) {
      const rule = this.selectedRule;
      const parent = rule?.satisfied_by?.[0];
      this.openSectionComposer({
        ruleId: rule?.id,
        componentId: this.component.id,
        section,
        ruleName: rule ? `${this.component.prefix}-${rule.rule_id}` : null,
        parentRuleId: parent?.id || null,
        parentRuleName: parent ? `${this.component.prefix}-${parent.rule_id}` : null,
      });
    },
    onOpenReplyComposer(reviewId) {
      this.openReplyComposer({
        reviewId,
        ruleId: this.selectedRule?.id,
        componentId: this.component.id,
        ruleName: this.selectedRule
          ? `${this.component.prefix}-${this.selectedRule.rule_id}`
          : null,
      });
    },
    afterComposerPosted(parentReviewId, snapshot) {
      const ruleId =
        snapshot.mode === "component" ? null : this.selectedRule?.id || snapshot.ruleId;
      if (!ruleId) {
        this.refreshComponent();
        return;
      }
      getRule(ruleId)
        .then((response) => {
          const idx = this.localRules.findIndex((r) => r.id === ruleId);
          if (idx >= 0) {
            this.localRules.splice(idx, 1, response.data);
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    onOpenComponentComposer() {
      this.openComponentComposer(this.component.id);
    },
    openCommentsPanel() {
      globalThis.location.href = `/components/${this.component.id}/triage`;
    },
    refreshComponent() {
      getComponent(this.component.id)
        .then((response) => {
          Object.assign(this.component, response.data);
          if (response.data.rules) {
            this.localRules = structuredClone(response.data.rules);
          }
        })
        .catch((error) => {
          this.alertOrNotifyResponse(error);
        });
    },
    toggleAdvancedFields(advanced_fields) {
      // Confirmation is now handled in RuleEditor component
      patchComponent(this.component.id, { advanced_fields })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.localAdvancedFields = advanced_fields;
        })
        .catch(this.alertOrNotifyResponse);
    },
    /**
     * open the unified Download/ExportModal. Listened from
     * ControlsCommandBar's Download button.
     */
    openExportModal() {
      this.showExportModal = true;
    },
    /**
     * emitted by ExportModal when the user confirms export.
     * Mirrors Project.vue's pattern but scopes component_ids to this single
     * component. Disposition data piggybacks the CSV/Excel formats per
     * Steps 3 and 4 — no extra wiring needed here.
     */
    executeExport({
      type,
      mode,
      componentIds,
      includeSrg,
      includeMemberships,
      excludeSatisfiedBy,
    }) {
      exportProjectData(this.project.id, type, {
        componentIds,
        mode,
        includeSrg,
        includeMemberships,
        excludeSatisfiedBy,
      })
        .then((url) => {
          window.open(url);
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
