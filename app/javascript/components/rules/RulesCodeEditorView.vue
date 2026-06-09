<template>
  <ControlsPageLayout
    :has-selected-rule="!!selectedRule"
    :show-command-bar="true"
    :show-filter-bar="filterBarVisible"
    :sidebar-width="2"
  >
    <!-- Command Bar -->
    <template #command-bar>
      <ControlsCommandBar
        :component="component"
        :selected-rule="selectedRule"
        :effective-permissions="effectivePermissions"
        :active-panel="activePanel"
        :read-only="false"
        :show-filter-toggle="true"
        :filter-bar-visible="filterBarVisible"
        :active-filter-count="activeFilterCount"
        @open-members="$bvModal.show(`members-modal-${component.id}`)"
        @toggle-panel="togglePanel"
        @toggle-filter-bar="toggleFilterBar"
        @clear-filters="clearAllFilters"
        @open-component-composer="onOpenComponentComposer"
      />

      <!-- Review Modal -->
      <RuleReviewModal
        v-if="selectedRule"
        :rule="selectedRule"
        :effective-permissions="effectivePermissions"
        :current-user-id="currentUserId"
        :read-only="isViewerOnly"
        @reviewSubmitted="handleReviewSubmitted"
      />
    </template>

    <!-- Filter Bar -->
    <template #filter-bar>
      <RuleFilterBar
        :filters="filters"
        :counts="counts"
        @update:filter="updateFilter"
        @reset="resetFilters"
      />
    </template>

    <!-- Left Sidebar Header (pinned — search, filter pills) -->
    <template #left-sidebar-header>
      <RuleSearchBar
        ref="sidebarSearchBar"
        :component-id="component.id"
        :project-prefix="component.prefix"
        :rules="rules"
        :read-only="false"
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
        :read-only="false"
        :nest-satisfied-rules-checked="navFilters.nestSatisfiedRulesChecked"
        :show-s-r-g-id-checked="navFilters.showSRGIdChecked"
        :has-active-filters="navHasActiveFilters"
        @reset-filters="onClearNavFilters"
      />
    </template>

    <!-- Modals -->
    <template #modals>
      <template v-if="selectedRule">
        <NewRuleModalForm
          :title="msg.cloneTitle"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="selectedRule.id"
          :selected-rule-text="`${component.prefix}-${selectedRule.rule_id}`"
        />

        <b-modal
          id="delete-rule-modal"
          :title="msg.deleteTitle"
          centered
          @ok="$root.$emit('delete:rule', selectedRule.id)"
        >
          <p class="my-2">{{ msg.deleteConfirmMessage }}</p>
          <b-alert v-if="selectedRule.locked" show variant="warning" class="mt-2">
            This control is currently <strong>locked</strong>. Deleting it will remove the lock and
            all associated data.
          </b-alert>
          <b-alert v-if="selectedRule.review_requestor_id" show variant="warning" class="mt-2">
            This control is currently <strong>under review</strong>. Deleting it will cancel the
            review.
          </b-alert>
          <template #modal-footer="{ cancel, ok }">
            <b-button @click="cancel()">Cancel</b-button>
            <b-button variant="danger" @click="ok()">{{ msg.deleteConfirmButton }}</b-button>
          </template>
        </b-modal>

        <!-- Also Satisfies Modal -->
        <AlsoSatisfiesModal
          :rules="rules"
          :selected-rule="selectedRule"
          :component-prefix="component.prefix"
          :show-s-r-g-id-checked="filters.showSRGIdChecked"
          @add-satisfied="onAddSatisfied"
        />
      </template>

      <!-- Related Rules Modal -->
      <RelatedRulesModal
        v-if="selectedRule"
        :read-only="selectedRule.locked || !!selectedRule.review_requestor_id"
        :rule="selectedRule"
        :rule-stig-id="`${component.prefix}-${selectedRule.rule_id}`"
      />

      <!-- Section Lock Comment Modal -->
      <b-modal
        v-model="sectionLockModal.visible"
        :title="sectionLockModalTitle"
        centered
        data-testid="section-lock-modal"
        @ok="confirmSectionLock"
        @cancel="cancelSectionLock"
      >
        <p>{{ sectionLockModalMessage }}</p>
        <b-form-group label="Comment (optional)" label-for="section-lock-comment">
          <b-form-textarea
            id="section-lock-comment"
            v-model="sectionLockModal.comment"
            placeholder="Reason for this change..."
            rows="2"
          />
        </b-form-group>
      </b-modal>
    </template>

    <!-- Main Content -->
    <template #main-content>
      <template v-if="selectedRule">
        <!-- Locked/Under Review warnings -->
        <p v-if="!isViewerOnly && selectedRule.locked" class="text-danger font-weight-bold">
          This control is locked and must first be unlocked if changes or deletion are required.
        </p>
        <p
          v-if="!isViewerOnly && selectedRule.review_requestor_id"
          class="text-danger font-weight-bold"
        >
          This control is under review and cannot be edited at this time.
        </p>

        <!-- Main Editor -->
        <RuleEditor
          :rule="selectedRule"
          :statuses="statuses"
          :read-only="isViewerOnly"
          :effective-permissions="effectivePermissions"
          :advanced_fields="localAdvancedFields"
          :additional_questions="component.additional_questions"
          :autosave-enabled="autosaveEnabled"
          :autosave-dirty="autosaveDirty"
          @clone="$bvModal.show('duplicate-rule-modal')"
          @delete="$bvModal.show('delete-rule-modal')"
          @save="saveRule($event)"
          @comment="commentFormSubmitted($event)"
          @lock="lockRule($event)"
          @unlock="unlockRule($event)"
          @open-review-modal="$bvModal.show('review-modal')"
          @open-related-modal="$bvModal.show('related-rules-modal')"
          @open-composer="onOpenComposer"
          @view-comments="onViewComments"
          @toggle-panel="togglePanel"
          @toggle-advanced-fields="toggleAdvancedFields"
          @toggle-section-lock="toggleSectionLock"
          @toggle-autosave="toggleAutosave"
        />
      </template>
    </template>

    <!-- Right Panels (Slideovers) - Using shared component -->
    <template #right-panels>
      <ControlsSidepanels
        :component="component"
        :selected-rule="selectedRule"
        :selected-rule-id="selectedRuleId"
        :active-panel="activePanel"
        :effective-permissions="effectivePermissions"
        :current-user-id="currentUserId"
        :statuses="statuses"
        :reviews-section-filter="reviewsSectionFilter"
        @close-panel="closePanel"
        @component-updated="refreshComponent"
        @open-reply-composer="onOpenReplyComposer"
      />

      <CommentComposerModal
        v-if="composerActive"
        v-bind="composerProps"
        :component-displayed-name="component.name"
        @posted="onComposerPosted"
        @hidden="onComposerHidden"
      />
    </template>
  </ControlsPageLayout>
</template>

<script>
import { toRef, computed } from "vue";
import { updateRule, updateSectionLocks } from "../../api/rulesApi";
import { createRuleReview } from "../../api/reviewsApi";
import { getComponent, patchComponent } from "../../api/componentsApi";
import RuleEditor from "./RuleEditor.vue";
import RuleSearchBar from "./RuleSearchBar.vue";
import RuleList from "./RuleList.vue";
import ActiveFilterPills from "./ActiveFilterPills.vue";
import AlsoSatisfiesModal from "./AlsoSatisfiesModal.vue";
import RelatedRulesModal from "./RelatedRulesModal.vue";
import RuleReviewModal from "./RuleReviewModal.vue";
import RuleFilterBar from "./RuleFilterBar.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import ControlsPageLayout from "./ControlsPageLayout.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import CommentComposerModal from "../components/CommentComposerModal.vue";
import ReplyComposerMixin from "../../mixins/ReplyComposerMixin.vue";
import { useRuleFilters, useSidebar } from "../../composables";
import { useRuleNavigation } from "../../composables/useRuleNavigation";
import { useRuleSelectionStore } from "../../stores/ruleSelection";
import { getFirstVisibleRule } from "../../utils/ruleSelectionUtils";
import { useRuleAutosave } from "../../composables/useRuleAutosave";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import { MESSAGE_LABELS } from "../../constants/terminology";
import { scrollToField } from "../../utils/searchHighlight";

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleSearchBar,
    RuleList,
    ActiveFilterPills,
    RuleEditor,
    AlsoSatisfiesModal,
    RelatedRulesModal,
    RuleReviewModal,
    RuleFilterBar,
    ControlsCommandBar,
    ControlsPageLayout,
    NewRuleModalForm,
    ControlsSidepanels,
    CommentComposerModal,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue, RoleComparisonMixin, ReplyComposerMixin],
  provide() {
    return {
      getCommentPhase: () => this.component.comment_phase || "open",
      getClosedReason: () => this.component.closed_reason || null,
      isCommentsClosed: () => (this.component.comment_phase || "open") !== "open",
    };
  },
  props: {
    effectivePermissions: {
      type: String,
      default: null,
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    project: {
      type: Object,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    availableRoles: {
      type: Array,
      required: true,
    },
  },
  setup(props) {
    const rulesRef = toRef(props, "rules");
    const componentId = props.component.id;
    const ruleStore = useRuleSelectionStore();

    const selectedRuleId = computed(() => ruleStore.selectedRuleId);
    const selectedRule = computed(() => {
      if (ruleStore.selectedRuleId === null) return null;
      return rulesRef.value.find((r) => r.id === ruleStore.selectedRuleId) || null;
    });

    const { filters, counts, setFilter, resetFilters, activeFilterCount } = useRuleFilters(
      rulesRef,
      componentId,
    );
    const nav = useRuleNavigation(rulesRef, props.component.prefix, componentId, filters);
    const { activePanel, togglePanel, openPanel, closePanel } = useSidebar();
    const autosave = useRuleAutosave(selectedRule, { componentId, onAutoSave: null });

    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    };

    const saved = localStorage.getItem(`ruleNavigatorFilters-${componentId}`);
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        const restorableKeys = [
          "search",
          "acFilterChecked",
          "aimFilterChecked",
          "adnmFilterChecked",
          "naFilterChecked",
          "nydFilterChecked",
          "nurFilterChecked",
          "urFilterChecked",
          "lckFilterChecked",
          "showSRGIdChecked",
          "sortBySRGIdChecked",
          "nestSatisfiedRulesChecked",
        ];
        restorableKeys.forEach((key) => {
          if (key in parsed && key in filters.value) {
            filters.value[key] = parsed[key];
          }
        });
      } catch (e) {
        // Use defaults
      }
    }

    return {
      ruleStore,
      selectedRuleId,
      selectedRule,
      selectRule: (ruleId) => ruleStore.selectRule(ruleId),
      deselectRule: (ruleId) => ruleStore.deselectRule(ruleId),
      navFilters: nav.filters,
      navFilteredRules: nav.filteredRules,
      navHasActiveFilters: nav.hasActiveFilters,
      navClearFilters: nav.clearFilters,
      navRemoveFilter: nav.removeFilter,
      navOnSearchUpdated: nav.onSearchUpdated,
      filters,
      counts,
      activeFilterCount,
      setFilter,
      resetFilters,
      updateFilter,
      activePanel,
      togglePanel,
      openPanel,
      closePanel,
      autosaveEnabled: autosave.enabled,
      autosaveDirty: autosave.isDirty,
      toggleAutosave: autosave.toggle,
      markAutosaveDirty: autosave.markDirty,
      resetAutosaveTimer: autosave.resetTimer,
      destroyAutosave: autosave.destroy,
      autosaveOptions: { componentId, onAutoSave: null },
    };
  },
  data() {
    const componentId = this.component.id;
    const savedFilterBar = localStorage.getItem(`filterBarVisible-${componentId}`);
    return {
      localAdvancedFields: this.component.advanced_fields,
      filterBarVisible: savedFilterBar === "true",
      sectionLockModal: {
        visible: false,
        section: null,
        isLocking: false,
        comment: "",
      },
      msg: MESSAGE_LABELS,
      reviewsSectionFilter: "all",
    };
  },
  computed: {
    sectionLockModalTitle() {
      const s = this.sectionLockModal;
      return s.isLocking
        ? "Lock " + (s.section || "") + " Section"
        : "Unlock " + (s.section || "") + " Section";
    },
    sectionLockModalMessage() {
      const s = this.sectionLockModal;
      return s.isLocking
        ? "Lock the " + (s.section || "") + " section? Locked fields will be read-only for authors."
        : "Unlock the " + (s.section || "") + " section? Fields will become editable again.";
    },
    isViewerOnly() {
      return this.effectivePermissions === "viewer";
    },
  },
  mounted() {
    this.ruleStore.init(this.$router, this.component.id);
    if (this.ruleStore.selectedRuleId === null && this.rules.length > 0) {
      const firstVisible = getFirstVisibleRule(this.rules);
      if (firstVisible) this.ruleStore.selectRule(firstVisible.id);
    }

    this.autosaveOptions.onAutoSave = (ruleId) => {
      this.$root.$emit("refresh:rule", ruleId);
    };
    if (this.selectedRuleId) {
      setTimeout(() => {
        this.$root.$emit("refresh:rule", this.selectedRuleId);
      }, 1);
    }
    this.$root.$on("update:rule", this.markAutosaveDirty);
    this.$root.$on("update:check", this.markAutosaveDirty);
    this.$root.$on("update:description", this.markAutosaveDirty);
    this.$root.$on("update:disaDescription", this.markAutosaveDirty);
  },
  beforeDestroy() {
    this.$root.$off("update:rule", this.markAutosaveDirty);
    this.$root.$off("update:check", this.markAutosaveDirty);
    this.$root.$off("update:description", this.markAutosaveDirty);
    this.$root.$off("update:disaDescription", this.markAutosaveDirty);
    this.destroyAutosave();
  },
  methods: {
    toggleFilterBar() {
      this.filterBarVisible = !this.filterBarVisible;
      localStorage.setItem(`filterBarVisible-${this.component.id}`, String(this.filterBarVisible));
    },
    clearAllFilters() {
      this.resetFilters();
      this.navClearFilters();
      this.$nextTick(() => {
        if (this.$refs.sidebarSearchBar) {
          this.$refs.sidebarSearchBar.setSearchValue("");
        }
      });
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
      if (this.selectedRule && snapshot.mode !== "component") {
        this.$root.$emit("refresh:rule", this.selectedRule.id, "all");
      }
    },
    onOpenComponentComposer() {
      this.openComponentComposer(this.component.id);
    },
    onAddSatisfied(ruleId, parentRuleId) {
      this.$root.$emit("addSatisfied:rule", ruleId, parentRuleId);
    },
    saveRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
      this.resetAutosaveTimer();
      updateRule(rule.id, { ...rule, audit_comment: comment })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id);
        })
        .catch(this.alertOrNotifyResponse);
    },
    commentFormSubmitted(comment) {
      if (!comment.trim()) return;
      const rule = this.selectedRule;
      if (!rule) return;
      createRuleReview(rule.id, { action: "comment", comment: comment })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    handleReviewSubmitted() {
      const rule = this.selectedRule;
      if (rule) {
        this.$root.$emit("refresh:rule", rule.id, "all");
        if (rule.satisfied_by?.length > 0) {
          rule.satisfied_by.forEach((r) => {
            this.$root.$emit("refresh:rule", r.id, "all");
          });
        }
      }
    },
    toggleSectionLock(section) {
      const rule = this.selectedRule;
      if (!rule) return;
      const isLocked = !!(rule.locked_fields || {})[section];
      this.sectionLockModal = {
        visible: true,
        section,
        isLocking: !isLocked,
        comment: "",
      };
    },
    confirmSectionLock() {
      const { section, isLocking, comment } = this.sectionLockModal;
      const rule = this.selectedRule;
      if (!rule) return;
      this.sectionLockModal.visible = false;
      updateSectionLocks(rule.id, {
        section,
        locked: isLocking,
        comment: comment.trim() || undefined,
      })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    cancelSectionLock() {
      this.sectionLockModal.visible = false;
    },
    toggleAdvancedFields(advancedFields) {
      patchComponent(this.component.id, { advanced_fields: advancedFields })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.localAdvancedFields = advancedFields;
        })
        .catch(this.alertOrNotifyResponse);
    },
    lockRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
      createRuleReview(rule.id, {
        component_id: rule.component_id,
        action: "lock_control",
        comment: (comment || "").trim() || "Locked",
      })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    unlockRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
      createRuleReview(rule.id, {
        component_id: rule.component_id,
        action: "unlock_control",
        comment: (comment || "").trim() || "Unlocked",
      })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    refreshComponent() {
      getComponent(this.component.id)
        .then((response) => {
          Object.keys(response.data).forEach((key) => {
            this.$set(this.component, key, response.data[key]);
          });
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
