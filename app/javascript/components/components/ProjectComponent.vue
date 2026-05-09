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

        <!-- Comment composer modal. Two modes: rule-scoped (selectedRule
             present) or component-scoped (componentComposerActive). -->
        <CommentComposerModal
          v-if="selectedRule || componentComposerActive"
          :component-id="component.id"
          :rule-id="componentComposerActive ? null : selectedRule.id"
          :rule-displayed-name="
            componentComposerActive ? '' : `${component.prefix}-${selectedRule.rule_id}`
          "
          :component-displayed-name="component.name"
          :initial-section="composerSection"
          :reply-to-review-id="composerReplyToId"
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
          :selected-rule-id="selectedRuleId"
          :active-panel="activePanel"
          :effective-permissions="effective_permissions"
          :current-user-id="current_user_id"
          :statuses="statuses"
          :read-only="true"
          @close-panel="closePanel"
          @component-updated="refreshComponent"
          @rule-selected="handleRuleSelected"
          @open-reply-composer="onOpenReplyComposer"
        />
      </template>
    </ControlsPageLayout>
  </div>
</template>

<script>
import { ref } from "vue";
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
import ExportModal from "../shared/ExportModal.vue";

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
    // Local clone of the rules array so reactivity is owned by Vue (not
    // the prop). Mutations via this ref reliably propagate through
    // useRuleSelection → selectedRule → RuleEditor → SectionCommentIcon.
    // Mirrors the pattern used by Rules.vue in the editor pack.
    const localRules = ref(structuredClone(props.initialComponentState.rules || []));

    const { selectedRuleId, openRuleIds, selectedRule, selectRule, deselectRule } =
      useRuleSelection(localRules, componentId, { autoSelectFirst: true });

    const { filters, counts, setFilter } = useRuleFilters(localRules, componentId);

    const { activePanel, togglePanel, closePanel } = useSidebar();

    const handleRuleSelected = selectRule;
    const handleRuleDeselected = deselectRule;

    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    };

    return {
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
      // section pre-selected on the comment composer when a
      // SectionCommentIcon click bubbles open-composer up to here.
      composerSection: null,
      // top-level review id when the composer is opened in reply mode
      // (CommentThread's "Reply" buttons emit open-reply-composer up
      // through ControlsSidepanels → here).
      composerReplyToId: null,
      componentComposerActive: false,
      // per-component editor Download surface.
      // Mode-aware ExportModal (Working Copy / Vendor Submission /
      // STIG-Ready Publish Draft / Backup) hits the project export
      // route scoped to this single component.
      showExportModal: false,
      availableExportModes: ["working_copy", "vendor_submission", "published_stig", "backup"],
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
    if (this.queriedRule && this.queriedRule.id) {
      this.selectRule(this.queriedRule.id);
      // replaceState (not pushState) so back returns to the calling page.
      window.history.replaceState({}, "", `/components/${this.component.id}`);
    }
  },
  methods: {
    /**
     * open the comment composer with a pre-selected section.
     * Triggered when SectionCommentIcon emits open-composer; the event
     * bubbles up RuleFormGroup → form → UnifiedRuleForm → RuleEditor.
     */
    onOpenComposer(section) {
      this.composerSection = section;
      this.composerReplyToId = null;
      this.$bvModal.show("comment-composer-modal");
    },
    onOpenReplyComposer(reviewId) {
      this.composerSection = null;
      this.composerReplyToId = reviewId;
      this.$bvModal.show("comment-composer-modal");
    },
    /**
     * Refresh the rule whose composer just posted (in-place splice into
     * the rules array) so reactivity reliably propagates to RuleReviews
     * + the per-section pending-count badges. Object.assign on the whole
     * component drops Vue 2 reactivity for nested arrays in this prop
     * tree, so we mirror Rules.vue's per-rule splice pattern.
     */
    onComposerPosted() {
      const ruleId = this.componentComposerActive ? null : this.selectedRule?.id;
      this.composerReplyToId = null;
      this.composerSection = null;
      this.componentComposerActive = false;
      if (!ruleId) {
        this.refreshComponent();
        return;
      }
      axios
        .get(`/rules/${ruleId}`, { headers: { Accept: "application/json" } })
        .then((response) => {
          const idx = this.localRules.findIndex((r) => r.id === ruleId);
          if (idx >= 0) {
            this.localRules.splice(idx, 1, response.data);
          }
        })
        .catch(this.alertOrNotifyResponse);
    },
    onComposerHidden() {
      this.composerReplyToId = null;
      this.componentComposerActive = false;
    },
    onOpenComponentComposer() {
      this.composerSection = null;
      this.composerReplyToId = null;
      this.componentComposerActive = true;
      this.$nextTick(() => this.$bvModal.show("comment-composer-modal"));
    },
    openCommentsPanel() {
      globalThis.location.href = `/components/${this.component.id}/triage`;
    },
    refreshComponent() {
      axios
        .get(`/components/${this.component.id}.json`)
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
      let url = `/projects/${this.project.id}/export/${type}?component_ids=${componentIds.join(",")}`;
      if (mode) url += `&mode=${mode}`;
      if (includeSrg) url += `&include_srg=true`;
      if (includeMemberships === false) url += `&include_memberships=false`;
      if (excludeSatisfiedBy) url += `&exclude_satisfied_by=true`;
      axios
        .get(url)
        .then(() => {
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
