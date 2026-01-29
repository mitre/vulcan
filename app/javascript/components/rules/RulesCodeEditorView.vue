<template>
  <div>
    <!-- Command Bar - Full Width -->
    <template v-if="selectedRule()">
      <div class="command-bar bg-light px-3 py-2 mb-3">
        <div class="d-flex align-items-center justify-content-between flex-wrap">
          <!-- Group 1: Context (left) -->
          <div class="command-group context-group d-flex align-items-center">
            <h5 class="mb-0 mr-2">
              <b-icon
                v-if="selectedRule().locked"
                icon="lock"
                aria-hidden="true"
                class="text-warning"
              />
              <b-icon
                v-if="selectedRule().review_requestor_id"
                icon="file-earmark-search"
                aria-hidden="true"
                class="text-info"
              />
              <b-icon
                v-if="selectedRule().changes_requested"
                icon="exclamation-triangle"
                aria-hidden="true"
                class="text-danger"
              />
              <a
                class="text-dark"
                :href="`/components/${selectedRule().component_id}/${component.prefix}-${selectedRule().rule_id}`"
              >
                {{ `${component.prefix}-${selectedRule().rule_id}` }}
              </a>
              <small class="text-muted ml-1">// {{ selectedRule().version }}</small>
            </h5>
            <small v-if="lastEditor" class="text-muted">
              Updated {{ friendlyDateTime(selectedRule().updated_at) }} by {{ lastEditor }}
            </small>
          </div>

          <!-- Group 2: Actions -->
          <div class="command-group actions-group">
            <b-button-group size="sm">
              <!-- Clone -->
              <b-button v-b-modal.duplicate-rule-modal variant="outline-info">
                <b-icon icon="files" /> Clone
              </b-button>
              <!-- Delete (admin only) -->
              <b-button
                v-if="effectivePermissions === 'admin'"
                v-b-modal.delete-rule-modal
                variant="outline-danger"
                :disabled="isReadOnly"
              >
                <b-icon icon="trash" /> Delete
              </b-button>
              <!-- Save -->
              <CommentModal
                title="Save Control"
                message="Provide a comment that summarizes your changes to this control."
                :require-non-empty="true"
                button-text="Save"
                button-variant="outline-success"
                button-size="sm"
                :button-disabled="isReadOnly"
                wrapper-class="d-inline-block"
                @comment="saveRule($event)"
              />
              <!-- Comment -->
              <CommentModal
                title="Comment"
                message="Submit general feedback on the control"
                :require-non-empty="true"
                button-text="Comment"
                button-variant="outline-secondary"
                button-size="sm"
                :button-disabled="false"
                wrapper-class="d-inline-block"
                @comment="commentFormSubmitted($event)"
              />
              <!-- Review -->
              <b-button v-b-modal.review-modal variant="outline-primary" size="sm">
                <b-icon icon="clipboard-check" /> Review
              </b-button>
            </b-button-group>
          </div>

          <!-- Group 3: Panels (right) -->
          <div class="command-group panels-group">
            <b-button-group size="sm">
              <b-button v-b-modal.related-rules-modal variant="outline-secondary">
                <b-icon icon="link-45deg" /> Related
              </b-button>
              <b-button
                :variant="activePanel === 'satisfies' ? 'secondary' : 'outline-secondary'"
                @click="togglePanel('satisfies')"
              >
                <b-icon icon="check2-square" /> Satisfies
              </b-button>
              <b-button
                :variant="activePanel === 'reviews' ? 'secondary' : 'outline-secondary'"
                @click="togglePanel('reviews')"
              >
                <b-icon icon="chat-left-text" /> Reviews
                <b-badge v-if="reviewCount > 0" variant="dark" pill class="ml-1">{{
                  reviewCount
                }}</b-badge>
              </b-button>
              <b-button
                :variant="activePanel === 'history' ? 'secondary' : 'outline-secondary'"
                @click="togglePanel('history')"
              >
                <b-icon icon="clock-history" /> History
              </b-button>
            </b-button-group>
          </div>
        </div>
      </div>

      <!-- Review Modal -->
      <RuleReviewModal
        :rule="selectedRule()"
        :effective-permissions="effectivePermissions"
        :current-user-id="currentUserId"
        :read-only="isViewerOnly"
        @reviewSubmitted="handleReviewSubmitted"
      />
    </template>

    <!-- Filter Bar - Full Width -->
    <RuleFilterBar
      :filters="filters"
      :counts="ruleStatusCounts"
      @update:filter="updateFilter"
      @reset="resetFilters"
    />

    <!-- Two-Column Layout -->
    <div class="row">
      <!-- Left Sidebar -->
      <div id="sidebar-wrapper" class="col-2 pr-0">
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
      </div>

      <!-- Main Content -->
      <template v-if="selectedRule()">
        <div class="col-10 mb-5">
          <!-- Modals (Clone and Delete) -->
          <NewRuleModalForm
            :title="'Clone Control'"
            :id-prefix="'duplicate'"
            :for-duplicate="true"
            :selected-rule-id="selectedRule().id"
            :selected-rule-text="`${component.prefix}-${selectedRule().rule_id}`"
            @ruleSelected="handleRuleSelected($event.id)"
          />

          <b-modal
            id="delete-rule-modal"
            title="Delete Control"
            centered
            @ok="$root.$emit('delete:rule', selectedRule().id)"
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
              <b-button
                variant="info"
                :disabled="selectedSatisfiesRuleIds.length === 0"
                @click="ok()"
              >
                Add {{ selectedSatisfiesRuleIds.length }} Control(s)
              </b-button>
            </template>
          </b-modal>

          <!-- Related Rules Modal -->
          <RelatedRulesModal
            :read-only="selectedRule().locked || !!selectedRule().review_requestor_id"
            :rule="selectedRule()"
            :rule-stig-id="`${component.prefix}-${selectedRule().rule_id}`"
          />

          <!-- Locked/Under Review warnings -->
          <p v-if="!isViewerOnly && selectedRule().locked" class="text-danger font-weight-bold">
            This control is locked and must first be unlocked if changes or deletion are required.
          </p>
          <p
            v-if="!isViewerOnly && selectedRule().review_requestor_id"
            class="text-danger font-weight-bold"
          >
            This control is under review and cannot be edited at this time.
          </p>

          <!-- Main Editor -->
          <RuleEditor
            :rule="selectedRule()"
            :statuses="statuses"
            :severities="severities"
            :severities_map="severities_map"
            :advanced_fields="component.advanced_fields"
            :additional_questions="component.additional_questions"
          />

          <!-- Right Sidebars -->
          <b-sidebar
            id="sidebar-satisfies"
            title="Also Satisfies"
            right
            shadow
            backdrop
            width="400px"
            :visible="activePanel === 'satisfies'"
            @hidden="activePanel = null"
          >
            <div class="px-3 py-2">
              <RuleSatisfactions
                :component="component"
                :rule="selectedRule()"
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
            @hidden="activePanel = null"
          >
            <div class="px-3 py-2">
              <RuleReviews
                :rule="selectedRule()"
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
            @hidden="activePanel = null"
          >
            <div class="px-3 py-2">
              <RuleHistories
                :rule="selectedRule()"
                :component="component"
                :statuses="statuses"
                :severities="severities"
              />
            </div>
          </b-sidebar>
        </div>
      </template>

      <template v-else>
        <div class="col-10">
          <p class="text-center text-muted mt-4">
            No control currently selected. Select a control on the left to view or edit.
          </p>
        </div>
      </template>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import RuleEditor from "./RuleEditor.vue";
import RuleNavigator from "./RuleNavigator.vue";
import RuleHistories from "./RuleHistories.vue";
import RuleReviews from "./RuleReviews.vue";
import RuleSatisfactions from "./RuleSatisfactions.vue";
import RelatedRulesModal from "./RelatedRulesModal.vue";
import RuleReviewModal from "./RuleReviewModal.vue";
import RuleFilterBar from "./RuleFilterBar.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import CommentModal from "../shared/CommentModal.vue";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin.vue";
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
    NewRuleModalForm,
    CommentModal,
    Multiselect,
  },
  mixins: [SelectedRulesMixin, DateFormatMixinVue, AlertMixinVue],
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
  data() {
    return {
      activePanel: null,
      filteredSelectRules: [],
      selectedSatisfiesRuleIds: [],
      showSRGIdChecked: null,
      filters: {
        search: "",
        acFilterChecked: true,
        aimFilterChecked: true,
        adnmFilterChecked: true,
        naFilterChecked: true,
        nydFilterChecked: true,
        nurFilterChecked: true,
        urFilterChecked: true,
        lckFilterChecked: true,
        nestSatisfiedRulesChecked: false,
        showSRGIdChecked: false,
        sortBySRGIdChecked: false,
      },
    };
  },
  computed: {
    reviewCount() {
      const rule = this.selectedRule();
      return rule?.reviews?.length || 0;
    },
    lastEditor() {
      const rule = this.selectedRule();
      if (rule?.histories?.length > 0) {
        return rule.histories[0].name || "Unknown User";
      }
      return null;
    },
    statusText() {
      const rule = this.selectedRule();
      if (!rule) return "";
      return rule.satisfied_by?.length > 0 ? "Applicable - Configurable" : rule.status;
    },
    isReadOnly() {
      const rule = this.selectedRule();
      if (!rule) return true;
      return rule.locked || !!rule.review_requestor_id;
    },
    isViewerOnly() {
      return this.effectivePermissions === "viewer";
    },
    ruleStatusCounts() {
      let ac = 0,
        aim = 0,
        adnm = 0,
        na = 0,
        nyd = 0;
      let nur = 0,
        ur = 0,
        lck = 0;

      for (const rule of this.rules) {
        // Status counts
        if (rule.status === "Applicable - Configurable") ac++;
        else if (rule.status === "Applicable - Inherently Meets") aim++;
        else if (rule.status === "Applicable - Does Not Meet") adnm++;
        else if (rule.status === "Not Applicable") na++;
        else if (rule.status === "Not Yet Determined") nyd++;

        // Review counts
        if (rule.locked) lck++;
        else if (rule.review_requestor_id) ur++;
        else nur++;
      }

      return { ac, aim, adnm, na, nyd, nur, ur, lck };
    },
  },
  watch: {
    selectedRuleId: {
      handler() {
        this.filterRules();
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
    this.loadFiltersFromStorage();
    this.updateShowSRGIdChecked();
  },
  beforeDestroy() {
    if (this.showSRGIdCheckedInterval) {
      clearInterval(this.showSRGIdCheckedInterval);
    }
  },
  methods: {
    togglePanel(panel) {
      this.activePanel = this.activePanel === panel ? null : panel;
    },
    updateFilter(filterName, value) {
      this.filters[filterName] = value;
      // Persist to localStorage for RuleNavigator sync
      localStorage.setItem(
        `ruleNavigatorFilters-${this.component.id}`,
        JSON.stringify(this.filters),
      );
      localStorage.setItem(`showSRGIdChecked-${this.component.id}`, this.filters.showSRGIdChecked);
    },
    resetFilters() {
      this.filters = {
        search: "",
        acFilterChecked: true,
        aimFilterChecked: true,
        adnmFilterChecked: true,
        naFilterChecked: true,
        nydFilterChecked: true,
        nurFilterChecked: true,
        urFilterChecked: true,
        lckFilterChecked: true,
        nestSatisfiedRulesChecked: false,
        showSRGIdChecked: false,
        sortBySRGIdChecked: false,
      };
      localStorage.setItem(
        `ruleNavigatorFilters-${this.component.id}`,
        JSON.stringify(this.filters),
      );
      localStorage.setItem(`showSRGIdChecked-${this.component.id}`, false);
    },
    loadFiltersFromStorage() {
      const saved = localStorage.getItem(`ruleNavigatorFilters-${this.component.id}`);
      if (saved) {
        try {
          this.filters = JSON.parse(saved);
        } catch (e) {
          // Use defaults
        }
      }
    },
    updateShowSRGIdChecked() {
      const componentId = this.component.id;
      this.showSRGIdChecked = localStorage.getItem(`showSRGIdChecked-${componentId}`);
      this.showSRGIdCheckedInterval = setInterval(() => {
        const newValue = localStorage.getItem(`showSRGIdChecked-${componentId}`);
        if (newValue !== this.showSRGIdChecked) {
          this.showSRGIdChecked = newValue;
          this.filterRules();
        }
      }, 1000);
    },
    filterRules() {
      const rule = this.selectedRule();
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
      const rule = this.selectedRule();
      if (rule) {
        this.$root.$emit("update:rule", { ...rule, status: newStatus });
      }
    },
    updateSeverity(newSeverity) {
      const rule = this.selectedRule();
      if (rule) {
        this.$root.$emit("update:rule", { ...rule, rule_severity: newSeverity });
      }
    },
    saveRule(comment) {
      const rule = this.selectedRule();
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
      const rule = this.selectedRule();
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
      const rule = this.selectedRule();
      if (rule) {
        this.$root.$emit("refresh:rule", rule.id, "all");
        if (rule.satisfied_by?.length > 0) {
          rule.satisfied_by.forEach((r) => {
            this.$root.$emit("refresh:rule", r.id, "all");
          });
        }
      }
    },
    addMultipleSatisfiedRules() {
      const rule = this.selectedRule();
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
.command-bar {
  position: sticky;
  top: 0;
  z-index: 100;
  border-radius: 0.375rem;
  border: 1px solid #dee2e6;
}

.command-group {
  margin: 0.25rem 0;
}

.actions-group,
.panels-group {
  margin-left: 1rem;
}

.context-group {
  min-width: 0;
  flex-shrink: 1;
}

.context-group h5 {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Responsive: Small screens (< 768px) */
@media (max-width: 767.98px) {
  .command-bar {
    padding: 0.75rem !important;
  }

  .command-bar > div {
    flex-direction: column;
    align-items: stretch !important;
    gap: 0.5rem;
  }

  .command-group {
    width: 100%;
    justify-content: flex-start;
  }

  .actions-group,
  .panels-group {
    width: 100%;
  }

  .actions-group >>> .btn-group,
  .panels-group >>> .btn-group {
    display: flex;
    flex-wrap: wrap;
    gap: 0.25rem;
  }

  .context-group h5 {
    font-size: 1rem;
  }

  .context-group small {
    display: block;
    margin-top: 0.25rem;
  }
}

/* Responsive: Medium screens (768px - 991px) */
@media (min-width: 768px) and (max-width: 991.98px) {
  .command-bar > div {
    gap: 0.5rem;
  }
}
</style>
