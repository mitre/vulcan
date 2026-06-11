<template>
  <div class="vulcan-editor-layout">
    <ControlsPageLayout
      :has-selected-rule="!!selectedRule"
      :show-command-bar="true"
      :show-filter-bar="filterBarVisible"
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
          :breadcrumbs="breadcrumbs"
          :show-filter-toggle="true"
          :filter-bar-visible="filterBarVisible"
          :active-filter-count="activeFilterCount"
          @release="requestRelease(component)"
          @open-members="$bvModal.show(`members-modal-${component.id}`)"
          @toggle-panel="togglePanel"
          @toggle-filter-bar="toggleFilterBar"
          @spreadsheet-updated="refreshComponent"
          @download="openExportModal"
          @open-component-composer="onOpenComponentComposer"
          @open-comments-panel="openCommentsPanel"
          @clear-filters="clearAllFilters"
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

      <!-- Left Sidebar Header (pinned — search, filter pills) -->
      <template #left-sidebar-header>
        <RuleSearchBar
          ref="sidebarSearchBar"
          :component-id="component.id"
          :project-prefix="component.prefix"
          :rules="rules"
          :read-only="true"
          :search-value="navFilters.search"
          @search-updated="navOnSearchUpdated"
          @clear-filters="onClearNavFilters"
          @search-result-selected="onNavSearchResultSelected"
        />
        <ActiveFilterPills
          :filters="navFilters"
          @remove-filter="onRemoveNavFilter"
          @clear-all="onClearNavFilters"
        />
      </template>

      <!-- Left Sidebar Body (scrollable — rule list) -->
      <template #left-sidebar>
        <RuleList
          :filtered-rules="navFilteredRules"
          :all-rules="rules"
          :component-id="component.id"
          :project-prefix="component.prefix"
          :read-only="true"
          :nest-satisfied-rules-checked="navFilters.nestSatisfiedRulesChecked"
          :show-s-r-g-id-checked="navFilters.showSRGIdChecked"
          :has-active-filters="navHasActiveFilters"
          @reset-filters="onClearNavFilters"
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

        <!-- Release confirmation (declarative — useConfirmRelease owns the state) -->
        <b-modal
          v-model="showModal"
          :title="releaseModal.title"
          :ok-title="releaseModal.okTitle"
          :ok-variant="releaseModal.okVariant"
          :cancel-title="releaseModal.cancelTitle"
          :busy="isReleasing"
          size="md"
          centered
          @ok="onConfirmRelease"
          @cancel="cancel"
        >
          <p>{{ releaseModal.body }}</p>
        </b-modal>

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
import { ref, computed, provide } from "vue";
import { getComponent, patchComponent } from "../../api/componentsApi";
import { getRule } from "../../api/rulesApi";
import { exportProjectData } from "../../api/projectsApi";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import { useSortRules } from "../../composables/useSortRules";
import { useConfirmRelease, RELEASE_CONFIRM_COPY } from "../../composables/useConfirmRelease";
import { useReplyComposer } from "../../composables/useReplyComposer";
import { useRuleFilters, useSidebar } from "../../composables";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { getFirstVisibleRule } from "../../utils/ruleSelectionUtils";
import { MESSAGE_LABELS } from "../../constants/terminology";
import ControlsPageLayout from "../rules/ControlsPageLayout.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import RuleFilterBar from "../rules/RuleFilterBar.vue";
import RuleSearchBar from "../rules/RuleSearchBar.vue";
import RuleList from "../rules/RuleList.vue";
import ActiveFilterPills from "../rules/ActiveFilterPills.vue";
import { useRuleNavigation } from "../../composables/useRuleNavigation";
import { scrollToField } from "../../utils/searchHighlight";
import RuleEditor from "../rules/RuleEditor.vue";
import RelatedRulesModal from "../rules/RelatedRulesModal.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import CommentComposerModal from "./CommentComposerModal.vue";
import ExportModal from "../shared/ExportModal.vue";

export default {
  name: "ProjectComponent",
  components: {
    ControlsPageLayout,
    ControlsCommandBar,
    RuleFilterBar,
    RuleSearchBar,
    RuleList,
    ActiveFilterPills,
    RuleEditor,
    RelatedRulesModal,
    ControlsSidepanels,
    CommentComposerModal,
    ExportModal,
  },
  // AlertMixin migrates in 0re.9 (useToast). DateFormatMixin and
  // RoleComparisonMixin were dead imports here — this component is the
  // PROVIDER for effectivePermissions (gates read the raw prop value) and
  // renders no dates itself.
  mixins: [AlertMixinVue],
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
    const effective_permissions = props.initialComponentState?.effective_permissions || null;
    provide("effectivePermissions", effective_permissions);
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

    const { filters, counts, setFilter, activeFilterCount } = useRuleFilters(
      localRules,
      componentId,
    );
    const nav = useRuleNavigation(
      localRules,
      props.initialComponentState.prefix,
      componentId,
      filters,
    );
    const { activePanel, togglePanel, closePanel } = useSidebar();

    const { compareRules } = useSortRules();

    // Release confirmation — declarative modal pattern, second consumer
    // after ComponentCard (.13.1). Copy from RELEASE_CONFIRM_COPY.
    const {
      showModal,
      isReleasing,
      requestRelease,
      cancel,
      confirm: confirmRelease,
    } = useConfirmRelease();

    // Bridge: useReplyComposer's onOpen/afterPosted callbacks need the
    // options-API instance ($bvModal.show, getRule refresh), which setup()
    // cannot reach in Vue 2.7 without getCurrentInstance (anti-pattern).
    // The bridge object is filled in created() — late binding, same
    // contract. Pattern established in ComponentComments.
    const composerBridge = { onOpen: null, afterPosted: null };
    const composer = useReplyComposer({
      onOpen: () => composerBridge.onOpen && composerBridge.onOpen(),
      afterPosted: (parentReviewId, snapshot) =>
        composerBridge.afterPosted && composerBridge.afterPosted(parentReviewId, snapshot),
    });

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
      navFilters: nav.filters,
      navFilteredRules: nav.filteredRules,
      navHasActiveFilters: nav.hasActiveFilters,
      navClearFilters: nav.clearFilters,
      navRemoveFilter: nav.removeFilter,
      navOnSearchUpdated: nav.onSearchUpdated,
      filters,
      counts,
      activeFilterCount,
      updateFilter,
      effective_permissions,
      activePanel,
      togglePanel,
      closePanel,
      compareRules,
      showModal,
      isReleasing,
      requestRelease,
      cancel,
      confirmRelease,
      releaseModal: RELEASE_CONFIRM_COPY,
      composerBridge,
      ...composer,
    };
  },
  data() {
    const componentId = this.initialComponentState.id;
    const savedFilterBar = localStorage.getItem(`filterBarVisible-${componentId}`);
    return {
      component: this.initialComponentState,
      localAdvancedFields: this.initialComponentState.advanced_fields,
      msg: MESSAGE_LABELS,
      showExportModal: false,
      availableExportModes: ["working_copy", "vendor_submission", "published_stig", "backup"],
      reviewsSectionFilter: "all",
      filterBarVisible: savedFilterBar === "true",
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
  created() {
    this.composerBridge.onOpen = () => this.$bvModal.show("comment-composer-modal");
    this.composerBridge.afterPosted = (parentReviewId, snapshot) =>
      this.afterComposerPosted(parentReviewId, snapshot);
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
    clearAllFilters() {
      this.navClearFilters();
      this.$nextTick(() => {
        if (this.$refs.sidebarSearchBar) {
          this.$refs.sidebarSearchBar.setSearchValue("");
        }
      });
    },
    toggleFilterBar() {
      this.filterBarVisible = !this.filterBarVisible;
      localStorage.setItem(`filterBarVisible-${this.component.id}`, String(this.filterBarVisible));
    },
    onNavSearchResultSelected(result) {
      const rule = this.rules.find((r) => r.id === result.id);
      if (rule) {
        if (!rule.histories) {
          this.$root.$emit("refresh:rule", rule.id);
        }
        this.ruleStore.selectRule(rule.id);
        if (result.matched_field) {
          this.$nextTick(() => {
            scrollToField(result.matched_field, result.searchQuery);
          });
        }
      }
    },
    onClearNavFilters() {
      this.navClearFilters();
      this.$nextTick(() => {
        if (this.$refs.sidebarSearchBar) {
          this.$refs.sidebarSearchBar.setSearchValue("");
        }
      });
    },
    onRemoveNavFilter(key) {
      this.navRemoveFilter(key);
      if (key === "search") {
        this.$nextTick(() => {
          if (this.$refs.sidebarSearchBar) {
            this.$refs.sidebarSearchBar.setSearchValue("");
          }
        });
      }
    },
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
    async onConfirmRelease(bvModalEvt) {
      if (bvModalEvt && bvModalEvt.preventDefault) bvModalEvt.preventDefault();
      const { success, response, error } = await this.confirmRelease();
      if (success) {
        this.alertOrNotifyResponse(response);
        this.$emit("projectUpdated");
      } else if (error) {
        this.alertOrNotifyResponse(error);
      }
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
