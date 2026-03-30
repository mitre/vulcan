<template>
  <ControlsPageLayout
    :has-selected-rule="!!selectedRule"
    :show-command-bar="true"
    :show-filter-bar="true"
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
        @open-members="$bvModal.show(`members-modal-${component.id}`)"
        @toggle-panel="togglePanel"
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
        :counts="ruleStatusCounts"
        @update:filter="updateFilter"
        @reset="resetFilters"
      />
    </template>

    <!-- Left Sidebar -->
    <template #left-sidebar>
      <RuleNavigator
        :component-id="component.id"
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :project-prefix="component.prefix"
        :effective-permissions="effectivePermissions"
        :open-rule-ids="openRuleIds"
        :external-filters="filters"
        @ruleSelected="handleRuleSelected($event)"
        @ruleDeselected="handleRuleDeselected($event)"
      />
    </template>

    <!-- Modals -->
    <template #modals>
      <!-- Members Modal -->
      <MembersModal
        :component="component"
        :effective-permissions="effectivePermissions"
        :available-roles="availableRoles"
      />

      <template v-if="selectedRule">
        <NewRuleModalForm
          :title="msg.cloneTitle"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="selectedRule.id"
          :selected-rule-text="`${component.prefix}-${selectedRule.rule_id}`"
          @ruleSelected="handleRuleSelected($event.id)"
        />

        <b-modal
          id="delete-rule-modal"
          :title="msg.deleteTitle"
          centered
          @ok="$root.$emit('delete:rule', selectedRule.id)"
        >
          <p class="my-2">{{ msg.deleteConfirmMessage }}</p>
          <b-alert v-if="selectedRule.locked" show variant="warning" class="mt-2">
            This control is currently <strong>locked</strong>. Deleting it will remove the lock and all associated data.
          </b-alert>
          <b-alert v-if="selectedRule.review_requestor_id" show variant="warning" class="mt-2">
            This control is currently <strong>under review</strong>. Deleting it will cancel the review.
          </b-alert>
          <template #modal-footer="{ cancel, ok }">
            <b-button @click="cancel()">Cancel</b-button>
            <b-button variant="danger" @click="ok()">{{ msg.deleteConfirmButton }}</b-button>
          </template>
        </b-modal>

        <!-- Also Satisfies Modal (multi-select) -->
        <b-modal
          id="also-satisfies-modal"
          title="Also Satisfies"
          centered
          size="lg"
          @ok="addMultipleSatisfiedRules"
          @hidden="clearSelectedRules"
        >
          <b-form-group :label="msg.satisfiesPrompt">
            <multiselect
              v-model="selectedSatisfiesRuleIds"
              :options="filteredSelectRules"
              :multiple="true"
              :close-on-select="false"
              :clear-on-select="false"
              :preserve-search="true"
              :placeholder="msg.satisfiesPlaceholder"
              label="text"
              track-by="value"
              :preselect-first="false"
            >
              <template slot="selection" slot-scope="{ values, isOpen }">
                <span v-if="values.length && !isOpen" class="multiselect__single">
                  {{ selectedCountLabel(values.length) }}
                </span>
              </template>
            </multiselect>
          </b-form-group>
          <div class="mt-2 text-muted">
            <small>{{ selectedCountLabel(selectedSatisfiesRuleIds.length) }}</small>
          </div>
          <template #modal-footer="{ cancel, ok }">
            <b-button @click="cancel()">Cancel</b-button>
            <b-button
              variant="info"
              :disabled="selectedSatisfiesRuleIds.length === 0"
              @click="ok()"
            >
              Add {{ selectedSatisfiesRuleIds.length }} {{ term.plural }}
            </b-button>
          </template>
        </b-modal>
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
        @close-panel="closePanel"
        @component-updated="refreshComponent"
        @rule-selected="handleRuleSelected"
      />
    </template>
  </ControlsPageLayout>
</template>

<script>
import { toRef } from "vue";
import axios from "axios";
import RuleEditor from "./RuleEditor.vue";
import RuleNavigator from "./RuleNavigator.vue";
import RelatedRulesModal from "./RelatedRulesModal.vue";
import RuleReviewModal from "./RuleReviewModal.vue";
import RuleFilterBar from "./RuleFilterBar.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import MembersModal from "../components/MembersModal.vue";
import ControlsPageLayout from "./ControlsPageLayout.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import { useRuleSelection, useRuleFilters, useSidebar } from "../../composables";
import { useRuleAutosave } from "../../composables/useRuleAutosave";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import Multiselect from "vue-multiselect";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import "vue-multiselect/dist/vue-multiselect.min.css";
import { RULE_TERM, MESSAGE_LABELS, selectedCountLabel } from "../../constants/terminology";
import { truncateId } from "../../utils/idFormatter";

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleNavigator,
    RuleEditor,
    RelatedRulesModal,
    RuleReviewModal,
    RuleFilterBar,
    ControlsCommandBar,
    MembersModal,
    ControlsPageLayout,
    NewRuleModalForm,
    Multiselect,
    ControlsSidepanels,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue, RoleComparisonMixin],
  props: {
    effectivePermissions: {
      type: String,
      required: true,
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
    // Convert props to refs for composables
    const rulesRef = toRef(props, "rules");
    const componentId = props.component.id;

    // Use composables
    const {
      selectedRuleId,
      openRuleIds,
      selectedRule,
      lastEditor,
      selectRule,
      deselectRule,
      closeAllRules,
      isRuleOpen,
    } = useRuleSelection(rulesRef, componentId, { autoSelectFirst: true });

    const {
      filters,
      counts,
      filteredRules,
      allStatusFiltersEnabled,
      allReviewFiltersEnabled,
      toggleFilter,
      setFilter,
      resetFilters,
    } = useRuleFilters(rulesRef, componentId);

    const { activePanel, togglePanel, openPanel, closePanel, isPanelActive } = useSidebar();

    // Autosave (F3)
    const autosaveOptions = { componentId, onAutoSave: null };
    const autosave = useRuleAutosave(selectedRule, autosaveOptions);

    // Backward compatibility: handleRuleSelected/handleRuleDeselected aliases
    const handleRuleSelected = selectRule;
    const handleRuleDeselected = deselectRule;

    // Backward compatibility: updateFilter wraps setFilter with localStorage persistence
    const updateFilter = (filterName, value) => {
      setFilter(filterName, value);
      // Persist to localStorage for RuleNavigator sync
      localStorage.setItem(`ruleNavigatorFilters-${componentId}`, JSON.stringify(filters.value));
      localStorage.setItem(`showSRGIdChecked-${componentId}`, filters.value.showSRGIdChecked);
    };

    // Load filters from localStorage on init
    // Only load status/review filters - display options use code defaults
    const loadFiltersFromStorage = () => {
      const saved = localStorage.getItem(`ruleNavigatorFilters-${componentId}`);
      if (saved) {
        try {
          const parsed = JSON.parse(saved);
          // Restore all user-set filter preferences
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
          // Use defaults — saved filter data is corrupt or invalid JSON
          // eslint-disable-next-line no-console
          console.error("Failed to load saved filters from localStorage:", e);
        }
      }
    };

    // Initialize filters from storage
    loadFiltersFromStorage();

    return {
      // Rule selection (from useRuleSelection)
      selectedRuleId,
      openRuleIds,
      selectedRule,
      lastEditor,
      selectRule,
      deselectRule,
      closeAllRules,
      isRuleOpen,
      handleRuleSelected,
      handleRuleDeselected,

      // Filters (from useRuleFilters)
      filters,
      counts,
      filteredRules,
      allStatusFiltersEnabled,
      allReviewFiltersEnabled,
      toggleFilter,
      setFilter,
      resetFilters,
      updateFilter,

      // Sidebar (from useSidebar)
      activePanel,
      togglePanel,
      openPanel,
      closePanel,
      isPanelActive,

      // Autosave (F3)
      autosaveEnabled: autosave.enabled,
      autosaveDirty: autosave.isDirty,
      toggleAutosave: autosave.toggle,
      markAutosaveDirty: autosave.markDirty,
      resetAutosaveTimer: autosave.resetTimer,
      destroyAutosave: autosave.destroy,
      autosaveOptions,
    };
  },
  data() {
    return {
      localAdvancedFields: this.component.advanced_fields,
      sectionLockModal: {
        visible: false,
        section: null,
        isLocking: false,
        comment: "",
      },
      term: RULE_TERM,
      msg: MESSAGE_LABELS,
      filteredSelectRules: [],
      selectedSatisfiesRuleIds: [],
      showSRGIdChecked: null,
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
    // Backward compatibility alias
    ruleStatusCounts() {
      return this.counts;
    },
  },
  watch: {
    selectedRuleId: {
      handler() {
        this.filterRulesForSatisfies();
      },
      immediate: true,
    },
  },
  mounted() {
    // Wire autosave callback to refresh rule history after auto-save
    this.autosaveOptions.onAutoSave = (ruleId) => {
      this.$root.$emit("refresh:rule", ruleId);
    };
    if (this.selectedRuleId) {
      setTimeout(() => {
        this.$root.$emit("refresh:rule", this.selectedRuleId);
      }, 1);
    }
    this.updateShowSRGIdChecked();
    // F3: Mark autosave dirty when any rule field changes
    this.$root.$on("update:rule", this.markAutosaveDirty);
  },
  beforeDestroy() {
    if (this.showSRGIdCheckedInterval) {
      clearInterval(this.showSRGIdCheckedInterval);
    }
    this.$root.$off("update:rule", this.markAutosaveDirty);
    this.destroyAutosave();
  },
  methods: {
    selectedCountLabel,
    updateShowSRGIdChecked() {
      const componentId = this.component.id;
      this.showSRGIdChecked = localStorage.getItem(`showSRGIdChecked-${componentId}`);
      this.showSRGIdCheckedInterval = setInterval(() => {
        const newValue = localStorage.getItem(`showSRGIdChecked-${componentId}`);
        if (newValue !== this.showSRGIdChecked) {
          this.showSRGIdChecked = newValue;
          this.filterRulesForSatisfies();
        }
      }, 1000);
    },
    filterRulesForSatisfies() {
      const rule = this.selectedRule;
      if (!rule) {
        this.filteredSelectRules = [];
        return;
      }
      this.filteredSelectRules = this.rules
        .filter((r) => {
          return (
            r.id !== rule.id &&
            r.satisfies.length === 0 &&
            !rule.satisfies.some((s) => s.id === r.id)
          );
        })
        .map((r) => {
          return {
            value: r.id,
            // Satisfaction relationships ALWAYS show SRG requirements (semantic requirement)
            text: truncateId(r.srg_id) || `${this.component.prefix}-${r.rule_id}`,
          };
        });
    },
    saveRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
      // Reset autosave timer — manual save takes priority
      this.resetAutosaveTimer();
      const payload = {
        rule: {
          ...rule,
          audit_comment: comment,
        },
      };
      axios
        .put(`/rules/${rule.id}`, payload)
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
      axios
        .post(`/rules/${rule.id}/reviews`, {
          review: {
            action: "comment",
            comment: comment,
          },
        })
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
      axios
        .patch(`/rules/${rule.id}/section_locks`, {
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
      // Confirmation is now handled in RuleEditor component
      const payload = {
        component: {
          advanced_fields: advancedFields,
        },
      };
      axios
        .patch(`/components/${this.component.id}`, payload)
        .then((response) => {
          this.alertOrNotifyResponse(response);
          // Update local data property (not prop) for proper reactivity through slots
          this.localAdvancedFields = advancedFields;
        })
        .catch(this.alertOrNotifyResponse);
    },
    lockRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
      axios
        .post(`/rules/${rule.id}/reviews`, {
          review: {
            component_id: rule.component_id,
            action: "lock_control",
            comment: (comment || "").trim() || "Locked",
          },
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
      axios
        .post(`/rules/${rule.id}/reviews`, {
          review: {
            component_id: rule.component_id,
            action: "unlock_control",
            comment: (comment || "").trim() || "Unlocked",
          },
        })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    addMultipleSatisfiedRules() {
      const rule = this.selectedRule;
      if (!rule) return;
      this.selectedSatisfiesRuleIds.forEach((item) => {
        const ruleId = typeof item === "object" ? item.value : item;
        this.$root.$emit("addSatisfied:rule", ruleId, rule.id);
      });
    },
    clearSelectedRules() {
      this.selectedSatisfiesRuleIds = [];
    },
    refreshComponent() {
      axios
        .get(`/components/${this.component.id}.json`)
        .then((response) => {
          // Update component properties in-place for Vue reactivity
          Object.assign(this.component, response.data);
        })
        .catch(this.alertOrNotifyResponse);
    },
  },
};
</script>

<style scoped>
/* Command bar styles are in ControlsCommandBar.vue */

.white-space-pre-wrap {
  white-space: pre-wrap;
}
</style>
