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
        @open-members="$bvModal.show('members-modal')"
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
          :severities="severities"
          :severities_map="severities_map"
          :read-only="isViewerOnly"
          :effective-permissions="effectivePermissions"
          :advanced_fields="component.advanced_fields"
          :additional_questions="component.additional_questions"
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
        :severities="severities"
        @close-panel="closePanel"
        @component-updated="refreshComponent"
        @rule-selected="handleRuleSelected"
      />
    </template>
  </ControlsPageLayout>
</template>

<script>
import { ref, computed, toRef, watch } from "vue";
import axios from "axios";
import RuleEditor from "./RuleEditor.vue";
import RuleNavigator from "./RuleNavigator.vue";
import RuleHistories from "./RuleHistories.vue";
import RuleReviews from "./RuleReviews.vue";
import RuleSatisfactions from "./RuleSatisfactions.vue";
import RelatedRulesModal from "./RelatedRulesModal.vue";
import RuleReviewModal from "./RuleReviewModal.vue";
import RuleFilterBar from "./RuleFilterBar.vue";
import ControlsCommandBar from "../shared/ControlsCommandBar.vue";
import MembersModal from "../components/MembersModal.vue";
import ControlsPageLayout from "./ControlsPageLayout.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import { useRuleSelection, useRuleFilters, useSidebar } from "../../composables";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import RoleComparisonMixin from "../../mixins/RoleComparisonMixin.vue";
import Multiselect from "vue-multiselect";
import History from "../shared/History.vue";
import UpdateComponentDetailsModal from "../components/UpdateComponentDetailsModal.vue";
import UpdateMetadataModal from "../components/UpdateMetadataModal.vue";
import AddQuestionsModal from "../components/AddQuestionsModal.vue";
import ControlsSidepanels from "../shared/ControlsSidepanels.vue";
import "vue-multiselect/dist/vue-multiselect.min.css";
import { RULE_TERM, MESSAGE_LABELS, selectedCountLabel } from "../../constants/terminology";

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleHistories,
    RuleReviews,
    RuleSatisfactions,
    RelatedRulesModal,
    RuleReviewModal,
    RuleFilterBar,
    ControlsCommandBar,
    MembersModal,
    ControlsPageLayout,
    NewRuleModalForm,
    Multiselect,
    History,
    UpdateComponentDetailsModal,
    UpdateMetadataModal,
    AddQuestionsModal,
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
    severities: {
      type: Array,
      required: true,
    },
    severities_map: {
      type: Object,
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
          // Only restore status and review filters, NOT display options
          // This ensures new display defaults take effect
          const statusReviewKeys = [
            "search",
            "acFilterChecked",
            "aimFilterChecked",
            "adnmFilterChecked",
            "naFilterChecked",
            "nydFilterChecked",
            "nurFilterChecked",
            "urFilterChecked",
            "lckFilterChecked",
          ];
          statusReviewKeys.forEach((key) => {
            if (key in parsed && key in filters.value) {
              filters.value[key] = parsed[key];
            }
          });
        } catch (e) {
          // Use defaults
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
    };
  },
  data() {
    return {
      term: RULE_TERM,
      msg: MESSAGE_LABELS,
      filteredSelectRules: [],
      selectedSatisfiesRuleIds: [],
      showSRGIdChecked: null,
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
    if (this.selectedRuleId) {
      setTimeout(() => {
        this.$root.$emit("refresh:rule", this.selectedRuleId);
      }, 1);
    }
    this.updateShowSRGIdChecked();
  },
  beforeDestroy() {
    if (this.showSRGIdCheckedInterval) {
      clearInterval(this.showSRGIdCheckedInterval);
    }
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
            text: JSON.parse(this.showSRGIdChecked)
              ? r.version
              : `${this.component.prefix}-${r.rule_id}`,
          };
        });
    },
    updateStatus(newStatus) {
      const rule = this.selectedRule;
      if (rule) {
        this.$root.$emit("update:rule", { ...rule, status: newStatus });
      }
    },
    updateSeverity(newSeverity) {
      const rule = this.selectedRule;
      if (rule) {
        this.$root.$emit("update:rule", { ...rule, rule_severity: newSeverity });
      }
    },
    saveRule(comment) {
      const rule = this.selectedRule;
      if (!rule) return;
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
      this.showReviewPane = false;
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
          // Update local component state for reactivity
          this.component.advanced_fields = advancedFields;
        })
        .catch(this.alertOrNotifyResponse);
    },
    lockRule(comment) {
      if (!comment.trim()) return;
      const rule = this.selectedRule;
      if (!rule) return;
      axios
        .post(`/rules/${rule.id}/reviews`, {
          review: {
            component_id: rule.component_id,
            action: "lock_control",
            comment: comment.trim(),
          },
        })
        .then((response) => {
          this.alertOrNotifyResponse(response);
          this.$root.$emit("refresh:rule", rule.id, "all");
        })
        .catch(this.alertOrNotifyResponse);
    },
    unlockRule(comment) {
      if (!comment.trim()) return;
      const rule = this.selectedRule;
      if (!rule) return;
      axios
        .post(`/rules/${rule.id}/reviews`, {
          review: {
            component_id: rule.component_id,
            action: "unlock_control",
            comment: comment.trim(),
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
      console.log("refreshComponent called, fetching:", `/components/${this.component.id}.json`);
      axios
        .get(`/components/${this.component.id}.json`)
        .then((response) => {
          console.log("refreshComponent response:", response.data);
          // Update component properties in-place for Vue reactivity
          Object.assign(this.component, response.data);
          console.log("Component after update:", this.component.name);
        })
        .catch((error) => {
          console.error("Failed to refresh component:", error);
        });
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
