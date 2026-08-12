<template>
  <div class="vulcan-editor-layout">
    <ControlsPageLayout
      :has-selected-rule="!!selectedRule"
      :show-command-bar="true"
      :show-filter-bar="filterBarVisible"
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
          :relocation-count="relocBacklogCount"
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
          :document-type="component.document_type"
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
          :pending-relocations="relocByRuleId"
          @reset-filters="onClearNavFilters"
          @add-comment="onSidebarAddComment"
          @reply-comment="onSidebarReplyComment"
        />
      </template>

      <!-- Main Content -->
      <template #main-content>
        <template v-if="selectedRule">
          <RuleEditor
            :rule="selectedRule"
            :statuses="statuses"
            :read-only="true"
            :view-only-page="true"
            :document-type="component.document_type"
            :effective-permissions="effective_permissions"
            :advanced_fields="localAdvancedFields"
            :additional_questions="component.additional_questions"
            :pending-relocation="relocByRuleId[selectedRule.id] || null"
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
        <!-- Related Rules Modal — structurally stig-only (keys off Rule
             SRG-version linkage); same kind guard as the editor sibling. -->
        <RelatedRulesModal
          v-if="selectedRule && !isSrgComponent"
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

        <!-- Relocation backlog (SRG kind) — read-only on the view page:
             the same panel the editor mounts, with adjudication and
             withdrawal disabled behind editor-pointing tooltips. -->
        <b-sidebar
          v-if="isSrgComponent"
          id="sidebar-relocations"
          :title="relocationTerms.backlogTitle"
          right
          shadow
          backdrop
          width="400px"
          :visible="activePanel === 'relocations'"
          @hidden="closePanel"
        >
          <RelocationBacklogPanel
            :markers="relocMarkers"
            :destination-options="relocDestinationOptions"
            :component-id="component.id"
            :initial-token="relocToken"
            :can-author="canAuthorComponent"
            :component-released="!!component.released"
            :view-only-page="true"
          />
        </b-sidebar>
      </template>
    </ControlsPageLayout>
  </div>
</template>

<script>
import { ref, computed, provide } from "vue";
import { getComponent, patchComponent } from "../../api/componentsApi";
import { getRule } from "../../api/rulesApi";
import { exportProjectData } from "../../api/projectsApi";
import { useSortRules } from "../../composables/useSortRules";
import { useToast } from "../../composables/useToast";
import { useConfirmRelease, RELEASE_CONFIRM_COPY } from "../../composables/useConfirmRelease";
import { useReplyComposer } from "../../composables/useReplyComposer";
import { useRuleFilters, useSidebar } from "../../composables";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { getFirstVisibleRule } from "../../utils/ruleSelectionUtils";
import { MESSAGE_LABELS, RELOCATION_TERM } from "../../constants/terminology";
import ControlsPageLayout from "../rules/ControlsPageLayout.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import RuleFilterBar from "../rules/RuleFilterBar.vue";
import RuleSearchBar from "../rules/RuleSearchBar.vue";
import RuleList from "../rules/RuleList.vue";
import ActiveFilterPills from "../rules/ActiveFilterPills.vue";
import { useRuleNavigation } from "../../composables/useRuleNavigation";
import { useRelocations } from "../../composables/useRelocations";
import { scrollToField } from "../../utils/searchHighlight";
import { roleGteTo } from "../../utils/roleComparison";
import RuleEditor from "../rules/RuleEditor.vue";
import RelatedRulesModal from "../rules/RelatedRulesModal.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import RelocationBacklogPanel from "../rules/RelocationBacklogPanel.vue";
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
    RelocationBacklogPanel,
    CommentComposerModal,
    ExportModal,
  },
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
      props.statuses,
    );
    const nav = useRuleNavigation(
      localRules,
      props.initialComponentState.prefix,
      componentId,
      filters,
      props.statuses,
    );
    const { activePanel, togglePanel, closePanel } = useSidebar();

    // Relocation STATE on the view page: badges, the read-only backlog
    // panel, and the command-bar count. All mutations live in the editor.
    const relocations = useRelocations(props.initialComponentState);

    const { compareRules } = useSortRules();
    const { alertOrNotifyResponse } = useToast();

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

    // Persistence lives in useRuleNavigation (it watches this same filters
    // ref and saves/restores) — no manual localStorage writes here.
    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
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
      relocMarkers: relocations.markers,
      relocByRuleId: relocations.markersByRuleId,
      relocToken: relocations.technologyToken,
      relocBacklogCount: relocations.srgBacklogCount,
      relocDestinationOptions: relocations.destinationOptions,
      relocFetch: relocations.fetchMarkers,
      relocFetchDestinations: relocations.fetchDestinations,
      compareRules,
      alertOrNotifyResponse,
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
      relocationTerms: RELOCATION_TERM,
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
    isSrgComponent() {
      return this.component.document_type === "srg";
    },
    canAuthorComponent() {
      return roleGteTo(this.effective_permissions, "author");
    },
  },
  created() {
    this.composerBridge.onOpen = () => this.$bvModal.show("comment-composer-modal");
    this.composerBridge.afterPosted = (parentReviewId, snapshot) =>
      this.afterComposerPosted(parentReviewId, snapshot);
    // Relocation markers exist only for SRG authoring; a load failure
    // surfaces as a toast rather than silently hiding the badges.
    if (this.isSrgComponent) {
      this.relocFetch().catch(this.alertOrNotifyResponse);
      // The backlog filter's vocabulary — named SRG options, never a
      // blank menu after the last proposal is adjudicated.
      this.relocFetchDestinations().catch(this.alertOrNotifyResponse);
    }
  },
  mounted() {
    this.ruleStore.init(this.$router, this.component.id);
    // A persisted selection can reference a requirement that no longer
    // exists — e.g. relocated away since the last visit. Clear the stale
    // id so the first-rule fallback fires instead of an empty pane.
    if (
      this.ruleStore.selectedRuleId !== null &&
      !this.localRules.some((rule) => rule.id === this.ruleStore.selectedRuleId)
    ) {
      this.ruleStore.deselectRule(this.ruleStore.selectedRuleId);
    }

    if (this.queriedRule && this.queriedRule.id) {
      this.ruleStore.selectRule(this.queriedRule.id);
    } else if (this.ruleStore.selectedRuleId === null && this.localRules.length > 0) {
      const firstVisible = getFirstVisibleRule(this.localRules);
      if (firstVisible) this.ruleStore.selectRule(firstVisible.id);
    }

    // The sidebar asks for a requirement to be refreshed when the one selected
    // is missing detail the collection does not carry. The editor page has
    // always answered that; this page emitted it and nobody listened.
    this.$root.$on("refresh:rule", this.refreshRule);

    // Whatever is selected on arrival needs the same treatment as one selected
    // by clicking, or the first requirement shown is the only one without it.
    if (this.ruleStore.selectedRuleId) this.refreshRule(this.ruleStore.selectedRuleId);
  },
  beforeDestroy() {
    this.$root.$off("refresh:rule", this.refreshRule);
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
    onOpenComposer(section, rule = this.selectedRule) {
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
    // Sidebar comments-modal entry points — same contract as the editor
    // page: the row's own rule, and the comment row's identity for replies.
    onSidebarAddComment(rule) {
      this.onOpenComposer(null, rule);
    },
    onSidebarReplyComment(row) {
      this.openReplyComposer({
        reviewId: row.id,
        ruleId: row.rule_id,
        componentId: row.component_id || this.component.id,
        ruleName: row.rule_displayed_name || null,
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
      this.refreshRule(ruleId);
    },
    // Replaces one requirement in the list with the full record from the
    // per-requirement endpoint, which carries the detail the collection omits.
    // A response that is not a requirement is ignored rather than written in:
    // overwriting a good row with an empty payload loses the row from the
    // sidebar entirely, which is worse than missing the detail we came for.
    refreshRule(ruleId) {
      getRule(ruleId)
        .then((response) => {
          const fetched = response && response.data;
          if (!fetched || fetched.id === undefined) return;

          const idx = this.localRules.findIndex((r) => r.id === ruleId);
          if (idx >= 0) {
            this.localRules.splice(idx, 1, fetched);
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
