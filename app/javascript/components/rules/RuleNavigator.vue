<template>
  <div id="scrolling-sidebar" ref="sidebar" :style="sidebarStyle">
    <div class="mr-2">
      <!-- Find & Replace -->
      <FindAndReplace
        :component-id="componentId"
        :project-prefix="projectPrefix"
        :rules="rules"
        :read-only="readOnly"
        class="mb-2"
      />

      <!-- Rule search -->
      <p class="mb-2">
        <strong>Filter &amp; Search</strong>
        <span class="text-primary clickable float-right" @click="clearFilters">reset</span>
      </p>
      <div class="input-group">
        <input
          id="ruleSearch"
          ref="ruleSearch"
          type="text"
          class="form-control"
          :placeholder="navLabels.searchPlaceholder"
          @input="searchUpdated($event.target.value)"
        />
      </div>

      <b-form-checkbox
        v-model="filters.pendingCommentsOnly"
        size="sm"
        switch
        class="mt-2"
        data-test="filter-pending-comments-only"
      >
        Pending comments only
      </b-form-checkbox>

      <hr class="mt-2 mb-2" />

      <!-- Currently opened rules -->
      <p class="mt-0 mb-1 d-flex justify-content-between align-items-center spacing-responsive">
        <strong>{{ navLabels.openRules }}</strong>
        <template v-if="openRuleIds.length > 0">
          <span class="clickable text-primary" @click="rulesDeselected(openRules)">
            <b-icon icon="x" class="clickable" />
            close all
          </span>
        </template>
      </p>
      <div v-if="openRules.length === 0">
        <em>{{ navLabels.noRulesSelected }}</em>
      </div>
      <div v-else>
        <div
          v-for="rule in openRules"
          :key="`open-${rule.id}`"
          :class="ruleRowClass(rule)"
          class="d-flex justify-content-between text-responsive"
          @click="ruleSelected(rule)"
        >
          <span>
            <b-icon icon="x" aria-hidden="true" @click.stop="ruleDeselected(rule)" />
            <span v-if="filters.showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
              {{ truncateId(rule.srg_id) }}
            </span>
            <span v-else>{{ formatRuleId(rule.rule_id) }}</span>
          </span>
          <span>
            <span
              v-if="rulePending(rule) > 0"
              v-b-tooltip.hover
              :title="`${rulePending(rule)} pending comments`"
              :data-test="`rule-pending-comment-${rule.id}`"
              class="text-warning mr-1"
            >
              <b-icon icon="chat-left-text" aria-hidden="true" />
            </span>
            <i
              v-if="rule.satisfies.length > 0"
              v-b-tooltip.hover
              icon="diagram-3"
              title="Satisfies other"
              aria-hidden="true"
            />
            <i
              v-if="rule.satisfied_by.length > 0"
              v-b-tooltip.hover
              icon="files"
              title="Satisfied by other"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.review_requestor_id"
              v-b-tooltip.hover
              icon="file-earmark-search"
              title="Review requested"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.locked"
              v-b-tooltip.hover
              icon="lock"
              title="Locked"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.changes_requested"
              v-b-tooltip.hover
              icon="exclamation-triangle"
              title="Changes requested"
              aria-hidden="true"
            />
          </span>
        </div>
      </div>

      <hr class="mt-2 mb-2" />

      <!-- All project rules -->
      <p class="mt-0 mb-0 d-flex justify-content-between align-items-center spacing-responsive">
        <strong>{{ navLabels.allRules }}</strong>
        <template v-if="!readOnly">
          <span v-b-modal.create-rule-modal class="text-primary clickable">
            <b-icon v-b-modal.create-rule-modal icon="plus" /> add
          </span>
        </template>
      </p>

      <!-- New rule modal -->
      <NewRuleModalForm
        :title="navLabels.createNew"
        :for-duplicate="false"
        id-prefix="create"
        @ruleSelected="ruleSelected($event)"
      />

      <!-- All rules list -->
      <div v-for="rule in filteredRules" :key="`rule-${rule.id}`">
        <div
          :class="ruleRowClass(rule)"
          class="d-flex justify-content-between text-responsive"
          @click="ruleSelected(rule)"
        >
          <span>
            <!-- Expand/collapse toggle for parents with children -->
            <template v-if="filters.nestSatisfiedRulesChecked && rule.satisfies.length > 0">
              <b-icon
                :icon="isParentExpanded(rule.id) ? 'chevron-down' : 'chevron-right'"
                class="tree-toggle mr-1"
                @click="toggleParentExpanded(rule.id, $event)"
              />
            </template>
            <!-- Spacer for leaf nodes to align with parents that have chevrons -->
            <template v-else-if="filters.nestSatisfiedRulesChecked && hasParentRules">
              <span class="tree-toggle-spacer" />
            </template>
            <span v-if="filters.showSRGIdChecked" v-b-tooltip.hover :title="rule.srg_id">
              {{ truncateId(rule.srg_id) }}
            </span>
            <span v-else>
              {{ formatRuleId(rule.rule_id) }}
            </span>
            <!-- Child count badge for collapsed parents -->
            <b-badge
              v-if="filters.nestSatisfiedRulesChecked && rule.satisfies.length > 0"
              variant="secondary"
              pill
              class="ml-1 child-count"
            >
              {{ rule.satisfies.length }}
            </b-badge>
          </span>
          <span>
            <span
              v-if="rulePending(rule) > 0"
              v-b-tooltip.hover
              :title="`${rulePending(rule)} pending comments`"
              :data-test="`rule-pending-comment-${rule.id}`"
              class="text-warning mr-1"
            >
              <b-icon icon="chat-left-text" aria-hidden="true" />
            </span>
            <i
              v-if="rule.satisfies.length > 0"
              v-b-tooltip.hover
              icon="diagram-3"
              title="Satisfies other"
              aria-hidden="true"
            />

            <i
              v-if="rule.satisfied_by.length > 0"
              v-b-tooltip.hover
              icon="files"
              title="Satisfied by other"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.review_requestor_id"
              v-b-tooltip.hover
              icon="file-earmark-search"
              title="Review requested"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.locked"
              v-b-tooltip.hover
              icon="lock"
              title="Locked"
              aria-hidden="true"
            />
            <b-icon
              v-if="rule.changes_requested"
              v-b-tooltip.hover
              icon="exclamation-triangle"
              title="Changes requested"
              aria-hidden="true"
            />
          </span>
        </div>
        <div
          v-if="filters.nestSatisfiedRulesChecked && rule.satisfies.length > 0"
          v-show="isParentExpanded(rule.id)"
          class="nested-children"
        >
          <div
            v-for="satisfies in sortAlsoSatisfies(rule.satisfies)"
            :key="satisfies.id"
            :class="ruleRowClass(satisfies)"
            class="d-flex justify-content-between text-responsive child-row"
            @click="ruleSelected(satisfies)"
          >
            <span>
              <b-icon icon="chevron-right" />
              <!-- Nested satisfaction children ALWAYS show SRG IDs (no toggle) -->
              <!-- WHY: These represent SRG requirements, semantically SRG data not STIG rules -->
              <span v-b-tooltip.hover :title="satisfies.srg_id">
                {{ truncateId(satisfies.srg_id) }}
              </span>
            </span>
            <span>
              <b-icon
                v-if="satisfies.review_requestor_id"
                v-b-tooltip.hover
                icon="file-earmark-search"
                title="Review requested"
                aria-hidden="true"
              />
              <b-icon
                v-if="satisfies.locked"
                v-b-tooltip.hover
                icon="lock"
                title="Locked"
                aria-hidden="true"
              />
              <b-icon
                v-if="satisfies.changes_requested"
                v-b-tooltip.hover
                icon="exclamation-triangle"
                title="Changes requested"
                aria-hidden="true"
              />
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
//
// Expect component to emit `ruleSelected` event when
// a rule is selected from the list. This event means that
// the user wants to edit that specific rule.
// this.$emit('ruleSelected', rule)
//
// <RuleNavigator @ruleSelected="handleRuleSelected($event)" ... />
//
import _ from "lodash";
import axios from "axios";
import FindAndReplace from "./FindAndReplace.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
import { getDefaultFilters } from "../../composables/useRuleFilters";
import { NAVIGATOR_LABELS } from "../../constants/terminology";
import { truncateId } from "../../utils/idFormatter";
export default {
  name: "RuleNavigator",
  components: { FindAndReplace, NewRuleModalForm },
  props: {
    effectivePermissions: {
      type: String,
      default: "",
    },
    componentId: {
      type: Number,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    },
    selectedRuleId: {
      type: Number,
      required: false,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    openRuleIds: {
      type: Array,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    externalFilters: {
      type: Object,
      default: null,
    },
  },
  data: function () {
    return {
      navLabels: NAVIGATOR_LABELS,
      rule_form_rule_id: "",
      sidebarOffset: 0,
      expandedParents: new Set(), // Track which parent rules are expanded
      localFilters: getDefaultFilters(),
      truncateId, // Expose utility for template
    };
  },
  computed: {
    filters: {
      get() {
        return this.externalFilters || this.localFilters;
      },
      set(value) {
        // Only allow setting if using local filters (no external filters provided)
        if (!this.externalFilters) {
          this.localFilters = value;
        }
      },
    },
    hasParentRules() {
      return this.filteredRules.some((r) => r.satisfies && r.satisfies.length > 0);
    },
    sidebarStyle: function () {
      return {
        "max-height": `calc(100vh - ${this.sidebarOffset}px)`,
      };
    },
    // generates the options for the status checkboxes
    ruleStatusCounts: function () {
      // status counts
      let acCount = 0;
      let aimCount = 0;
      let adnmCount = 0;
      let naCount = 0;
      let nydCount = 0;
      let acSatisfiedByCount = 0;

      // review counts
      let nurCount = 0;
      let urCount = 0;
      let lckCount = 0;

      for (var i = 0; i < this.rules.length; i++) {
        const status = this.rules[i].status;
        const satisfiedByOther = this.rules[i].satisfied_by.length > 0;
        // Status counts
        if (status == "Applicable - Configurable") {
          acCount += 1;
          acSatisfiedByCount += satisfiedByOther ? 1 : 0;
        } else if (status == "Applicable - Inherently Meets") {
          aimCount += 1;
        } else if (status == "Applicable - Does Not Meet") {
          adnmCount += 1;
        } else if (status == "Not Applicable") {
          naCount += 1;
        } else if (status == "Not Yet Determined") {
          nydCount += 1;
        }

        // Review counts
        const hasReviewRequestor = this.rules[i].review_requestor_id != null;
        const isLocked = this.rules[i].locked;
        if (!hasReviewRequestor && !isLocked) {
          nurCount += 1;
        } else if (hasReviewRequestor) {
          urCount += 1;
        } else if (isLocked) {
          lckCount += 1;
        }
      }

      return {
        ac: acCount,
        aim: aimCount,
        adnm: adnmCount,
        na: naCount,
        acsb: acSatisfiedByCount, // applicable - configurable satisfied by other controls.
        nyd: nydCount,
        nur: nurCount,
        ur: urCount,
        lck: lckCount,
      };
    },
    // Filters down to all rules that apply to search & applied filters
    filteredRules: function () {
      return this.filterRules(this.rules);
    },
    // Filters down to open rules that also apply to search & applied filters
    openRules: function () {
      const openRules = this.rules.filter((rule) => this.openRuleIds.includes(rule.id));
      return openRules;
    },
  },
  watch: {
    filters: {
      handler(_) {
        localStorage.setItem(
          `ruleNavigatorFilters-${this.componentId}`,
          JSON.stringify(this.filters),
        );
        localStorage.setItem(`showSRGIdChecked-${this.componentId}`, this.filters.showSRGIdChecked);
      },
      deep: true,
    },
  },
  mounted: function () {
    // Restore status/review filters from localStorage, but keep display defaults
    if (localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`)) {
      try {
        const saved = JSON.parse(localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`));
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
          if (key in saved) {
            this.filters[key] = saved[key];
          }
        });
        if (this.$refs.ruleSearch) {
          this.$refs.ruleSearch.value = this.filters.search;
        }
      } catch (e) {
        localStorage.removeItem(`ruleNavigatorFilters-${this.componentId}`);
      }
    }
    window.addEventListener("scroll", this.handleScroll);
    this.handleScroll();
  },
  destroyed() {
    window.removeEventListener("scroll", this.handleScroll);
  },
  methods: {
    // Collapsible tree methods
    isParentExpanded(ruleId) {
      return this.expandedParents.has(ruleId);
    },
    toggleParentExpanded(ruleId, event) {
      // Prevent selecting the rule when clicking the expand/collapse toggle
      if (event) {
        event.stopPropagation();
      }
      if (this.expandedParents.has(ruleId)) {
        this.expandedParents.delete(ruleId);
      } else {
        this.expandedParents.add(ruleId);
      }
      // Force reactivity update since Set changes aren't tracked
      this.expandedParents = new Set(this.expandedParents);
    },
    searchUpdated: _.debounce(function (newSearch) {
      this.filters.search = newSearch;
    }, 500),
    // Event handler for when a rule is selected
    ruleSelected: function (rule) {
      if (!rule.histories) {
        this.$root.$emit("refresh:rule", rule.id);
      }
      this.$emit("ruleSelected", rule.id);
    },
    ruleDeselected: function (rule) {
      this.$emit("ruleDeselected", rule.id);
    },
    rulesDeselected: function (rules) {
      rules.forEach((rule) => {
        this.$emit("ruleDeselected", rule.id);
      });
    },
    // Dynamically set the class of each rule row
    ruleRowClass: function (rule) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.selectedRuleId == rule.id,
      };
    },
    // Helper to test if a rule's status is a currently selected filter checkboxes
    doesRuleHaveFilteredStatus: function (rule) {
      return (
        (!this.filters.acFilterChecked &&
          !this.filters.aimFilterChecked &&
          !this.filters.adnmFilterChecked &&
          !this.filters.naFilterChecked &&
          !this.filters.nydFilterChecked) ||
        (this.filters.acFilterChecked && rule.status == "Applicable - Configurable") ||
        (this.filters.aimFilterChecked && rule.status == "Applicable - Inherently Meets") ||
        (this.filters.adnmFilterChecked && rule.status == "Applicable - Does Not Meet") ||
        (this.filters.naFilterChecked && rule.status == "Not Applicable") ||
        (this.filters.nydFilterChecked && rule.status == "Not Yet Determined")
      );
    },
    doesRuleHaveFilteredReviewStatus: function (rule) {
      return (
        (!this.filters.nurFilterChecked &&
          !this.filters.urFilterChecked &&
          !this.filters.lckFilterChecked) ||
        (this.filters.nurFilterChecked && !rule.locked && !rule.review_requestor_id) ||
        (this.filters.urFilterChecked && !rule.locked && rule.review_requestor_id) ||
        (this.filters.lckFilterChecked && rule.locked)
      );
    },
    listSatisfiedRule: function (rule) {
      let showRule = true;
      if (this.filters.nestSatisfiedRulesChecked) {
        showRule = rule.satisfied_by.length === 0;
      }
      return showRule;
    },
    // Helper to filter & search a group of rules
    filterRules: function (rules) {
      let downcaseSearch = this.filters.search.toLowerCase();
      let sortedRules = [...rules];
      if (this.filters.sortBySRGIdChecked) {
        sortedRules.sort((a, b) => a.version.localeCompare(b.version));
      }

      let filteredRules = sortedRules.filter((rule) => {
        return (
          this.searchTextForRule(rule).includes(downcaseSearch) &&
          this.doesRuleHaveFilteredStatus(rule) &&
          this.doesRuleHaveFilteredReviewStatus(rule) &&
          (downcaseSearch.length > 0 || this.listSatisfiedRule(rule)) &&
          (!this.filters.pendingCommentsOnly || this.rulePending(rule) > 0)
        );
      });

      // When nesting is enabled, sort parents (rules that satisfy others) before leaves
      // This creates a logical tree structure in the UI
      if (this.filters.nestSatisfiedRulesChecked) {
        const parents = filteredRules.filter((rule) => rule.satisfies.length > 0);
        const leaves = filteredRules.filter((rule) => rule.satisfies.length === 0);
        filteredRules = [...parents, ...leaves];
      }

      return filteredRules;
    },
    sortAlsoSatisfies: function (rules) {
      return [...rules].sort((a, b) => a.rule_id.localeCompare(b.rule_id));
    },
    // pending comment count for a rule. Reads rule.comment_summary
    // populated by RuleBlueprint default fields. Returns 0 when missing so
    // the badge stays hidden for rules without any comments.
    rulePending: function (rule) {
      return (rule.comment_summary && rule.comment_summary.pending) || 0;
    },
    formatRuleId: function (id) {
      return `${this.projectPrefix}-${id}`;
    },
    // This is a super basic function that provides a single searchable string for a given rule
    // It does not do anything like exclude attributes from search depending on the rule status.
    // It is unclear at this time if that would be necessary or useful, but if that does become
    // the case then expect this function to change.
    searchTextForRule: function (rule) {
      const ruleSearchAttrs = [
        // "artifact_description",
        // "fix_id",
        "fixtext",
        // "fixtext_fixref",
        // "ident",
        // "ident_system",
        // "rule_id",
        "rule_severity",
        // "rule_weight",
        // "status",
        "status_justification",
        "title",
        "vendor_comments",
        // "version",
      ];
      const checkDescriptionSearchAttrs = [
        "content",
        // "content_ref_href",
        // "content_ref_name",
        // "system",
      ];
      const disaDescriptionSearchAttrs = [
        // "false_negatives",
        // "false_positives",
        // "ia_controls",
        // "mitigation_controls",
        // "mitigations",
        // "potential_impacts",
        // "responsibility",
        // "security_override_guidance",
        // "third_party_tools",
        "vuln_discussion",
      ];
      // Start with the rule ID as searchable
      let searchText = this.formatRuleId(rule.rule_id);
      // The `|| ''` statements below prevent the literal string 'undefined' from being part of the searchable text
      // Add all rule attrs for rule
      for (var attrIndex = 0; attrIndex < ruleSearchAttrs.length; attrIndex++) {
        searchText += ` | ${rule[ruleSearchAttrs[attrIndex]] || ""}`;
      }
      // Add all check attrs for each rule check
      for (var attrIndex = 0; attrIndex < checkDescriptionSearchAttrs.length; attrIndex++) {
        for (var checkIndex = 0; checkIndex < rule.checks_attributes.length; checkIndex++) {
          searchText += ` | ${
            rule.checks_attributes[checkIndex][checkDescriptionSearchAttrs[attrIndex]] || ""
          }`;
        }
      }
      // Add all descriptions attrs for each rule disa description
      for (var attrIndex = 0; attrIndex < disaDescriptionSearchAttrs.length; attrIndex++) {
        for (
          var descIndex = 0;
          descIndex < rule.disa_rule_descriptions_attributes.length;
          descIndex++
        ) {
          searchText += ` | ${
            rule.disa_rule_descriptions_attributes[descIndex][
              disaDescriptionSearchAttrs[attrIndex]
            ] || ""
          }`;
        }
      }
      return searchText.toLowerCase();
    },
    // Helper to clear all filters
    clearFilters: function () {
      this.$refs.ruleSearch.value = "";
      this.filters = getDefaultFilters();
    },
    handleScroll: function () {
      this.$nextTick(() => {
        // Get the distance from the top of the sidebar to the top of the page
        let top = this.$refs.sidebar?.getBoundingClientRect().top;
        // if top is set and greater than 0 then set the sidebar offset to keep
        // the scrollbar from going off the page
        this.sidebarOffset = top > 0 ? top : 0;
      });
    },
  },
};
</script>

<style scoped>
.parent-svg-container {
  width: 18px;
  height: 18px;
  margin-left: -0.1em;
  font-weight: 800;
}

.child-svg-container {
  width: 24px;
  height: 24px;
  margin-left: -0.4em;
  font-weight: 800;
}

.text-responsive {
  font-size: 0.9em;
  font-weight: 500;
}

.spacing-responsive {
  letter-spacing: -0.05em;
}
.ruleRow {
  padding: 0.25em;
}

.ruleRow:hover {
  background: rgb(0, 0, 0, 0.12);
}

.selectedRuleRow {
  background: rgba(66, 50, 50, 0.09);
}

.closeRuleButton {
  color: red;
  padding: 0.1em;
  border: 1px solid rgb(0, 0, 0, 0);
  box-sizing: border-box;
}

.closeRuleButton:hover {
  border: 1px solid red;
  border-radius: 0.2em;
}

#scrolling-sidebar {
  display: block;
  overflow-y: auto;
}

/* Mobile: limit sidebar height so main content is visible below */
@media (max-width: 767.98px) {
  #scrolling-sidebar {
    max-height: 40vh !important;
  }
}

.filter-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.15rem 0;
}

.filter-toggle {
  flex: 1;
}

.filter-count {
  font-size: 0.85em;
  color: #6c757d;
  min-width: 40px;
  text-align: right;
}

@media (min-width: 1200px) {
  .text-responsive {
    font-size: 1em;
    font-weight: 400;
  }
  .spacing-responsive {
    letter-spacing: 0.01em;
  }
}

/* Collapsible tree styles */
.tree-toggle {
  cursor: pointer;
  color: #6c757d;
  transition: transform 0.15s ease;
}

.tree-toggle:hover {
  color: #007bff;
}

/* Spacer for leaf nodes to align text with parent nodes */
.tree-toggle-spacer {
  display: inline-block;
  width: 1em;
  margin-right: 0.25rem;
}

.nested-children {
  margin-left: 1rem;
  border-left: 1px solid #dee2e6;
  padding-left: 0.5rem;
}

.child-row {
  font-size: 0.9em;
  color: #495057;
}

.child-count {
  font-size: 0.75em;
  font-weight: normal;
}
</style>
