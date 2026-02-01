<template>
  <ControlsPageLayout
    :has-selected-rule="!!selectedRule"
    :show-command-bar="true"
    :show-filter-bar="true"
    :sidebar-width="2"
  >
    <!-- Command Bar -->
    <template #command-bar>
      <RuleCommandBar
        v-if="selectedRule"
        :rule="selectedRule"
        :component-prefix="component.prefix"
        :effective-permissions="effectivePermissions"
        :current-user-id="currentUserId"
        :active-panel="activePanel"
        class="mb-3"
        @clone="$bvModal.show('duplicate-rule-modal')"
        @delete="$bvModal.show('delete-rule-modal')"
        @save="saveRule($event)"
        @comment="commentFormSubmitted($event)"
        @lock="lockRule($event)"
        @unlock="unlockRule($event)"
        @open-review-modal="$bvModal.show('review-modal')"
        @open-related-modal="$bvModal.show('related-rules-modal')"
        @toggle-panel="togglePanel($event)"
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
      <template v-if="selectedRule">
        <NewRuleModalForm
          :title="'Clone Control'"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="selectedRule.id"
          :selected-rule-text="`${component.prefix}-${selectedRule.rule_id}`"
          @ruleSelected="handleRuleSelected($event.id)"
        />

        <b-modal
          id="delete-rule-modal"
          title="Delete Control"
          centered
          @ok="$root.$emit('delete:rule', selectedRule.id)"
        >
        <p class="my-2">
          Are you sure you want to delete this control?<br />This cannot be undone.
        </p>
        <template #modal-footer="{ cancel, ok }">
          <b-button @click="cancel()">Cancel</b-button>
          <b-button variant="danger" @click="ok()">Permanently Delete Control</b-button>
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
        <b-form-group label="Select controls that this one satisfies:">
          <multiselect
            v-model="selectedSatisfiesRuleIds"
            :options="filteredSelectRules"
            :multiple="true"
            :close-on-select="false"
            :clear-on-select="false"
            :preserve-search="true"
            placeholder="Search and select controls..."
            label="text"
            track-by="value"
            :preselect-first="false"
          >
            <template slot="selection" slot-scope="{ values, isOpen }">
              <span v-if="values.length && !isOpen" class="multiselect__single">
                {{ values.length }} control(s) selected
              </span>
            </template>
          </multiselect>
        </b-form-group>
        <div class="mt-2 text-muted">
          <small>{{ selectedSatisfiesRuleIds.length }} control(s) selected</small>
        </div>
        <template #modal-footer="{ cancel, ok }">
          <b-button @click="cancel()">Cancel</b-button>
          <b-button variant="info" :disabled="selectedSatisfiesRuleIds.length === 0" @click="ok()">
            Add {{ selectedSatisfiesRuleIds.length }} Control(s)
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
          :advanced_fields="component.advanced_fields"
          :additional_questions="component.additional_questions"
        />
      </template>
    </template>

    <!-- Right Panels -->
    <template #right-panels>
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
            @ruleSelected="handleRuleSelected($event)"
          />
        </div>
      </b-sidebar>

      <b-sidebar
        id="sidebar-reviews"
        title="Reviews"
        right
        shadow
        backdrop
        width="400px"
        :visible="activePanel === 'reviews'"
        @hidden="closePanel"
      >
        <div v-if="selectedRule" class="px-3 py-2">
          <RuleReviews
            :rule="selectedRule"
            :effective-permissions="effectivePermissions"
            :current-user-id="currentUserId"
          />
        </div>
      </b-sidebar>

      <b-sidebar
        id="sidebar-history"
        title="History"
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
import RuleCommandBar from "./RuleCommandBar.vue";
import ControlsPageLayout from "./ControlsPageLayout.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import { useRuleSelection, useRuleFilters, useSidebar } from "../../composables";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import Multiselect from "vue-multiselect";
import "vue-multiselect/dist/vue-multiselect.min.css";

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
    RuleCommandBar,
    ControlsPageLayout,
    NewRuleModalForm,
    Multiselect,
  },
  mixins: [DateFormatMixinVue, AlertMixinVue],
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
    } = useRuleSelection(rulesRef, componentId);

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
    const loadFiltersFromStorage = () => {
      const saved = localStorage.getItem(`ruleNavigatorFilters-${componentId}`);
      if (saved) {
        try {
          const parsed = JSON.parse(saved);
          Object.keys(parsed).forEach((key) => {
            if (key in filters.value) {
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
      filteredSelectRules: [],
      selectedSatisfiesRuleIds: [],
      showSRGIdChecked: null,
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
  },
};
</script>

<style scoped>
/* Command bar styles are now in RuleCommandBar.vue */
</style>
