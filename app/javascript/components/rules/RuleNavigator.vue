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
          placeholder="Search controls..."
          @input="searchUpdated($event.target.value)"
        />
      </div>

      <!-- Filter by rule status -->
      <b-form-group class="mt-3" label="Filter by Control Status">
        <b-form-checkbox
          id="acFilterChecked-filter"
          v-model="filters.acFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="acFilterChecked-filter"
        >
          <span class="d-flex flex-column align-items-center">
            <span
              ><strong>({{ ruleStatusCounts.ac }})</strong> Applicable - Configurable
            </span>
            <small v-if="ruleStatusCounts.acsb" class="text-info"
              >{{ ruleStatusCounts.acsb }} Satisfied by other
            </small>
          </span>
        </b-form-checkbox>

        <b-form-checkbox
          id="aimFilterChecked-filter"
          v-model="filters.aimFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="aimFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.aim }})</strong> Applicable - Inherently Meets
        </b-form-checkbox>

        <b-form-checkbox
          id="adnmFilterChecked-filter"
          v-model="filters.adnmFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="adnmFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.adnm }})</strong> Applicable - Does Not Meet
        </b-form-checkbox>

        <b-form-checkbox
          id="naFilterChecked-filter"
          v-model="filters.naFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="naFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.na }})</strong> Not Applicable
        </b-form-checkbox>

        <b-form-checkbox
          id="nydFilterChecked-filter"
          v-model="filters.nydFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="nydFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.nyd }})</strong> Not Yet Determined
        </b-form-checkbox>
      </b-form-group>

      <!-- Filter by review status -->
      <b-form-group class="mt-3" label="Filter by Review Status">
        <b-form-checkbox
          id="nurFilterChecked-filter"
          v-model="filters.nurFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="nurFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.nur }})</strong> Not Under Review
        </b-form-checkbox>

        <b-form-checkbox
          id="urFilterChecked-filter"
          v-model="filters.urFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="urFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.ur }})</strong> Under Review
        </b-form-checkbox>

        <b-form-checkbox
          id="lckFilterChecked-filter"
          v-model="filters.lckFilterChecked"
          size="sm"
          class="mb-1 unselectable"
          name="lckFilterChecked-filter"
        >
          <strong>({{ ruleStatusCounts.lck }})</strong> Locked
        </b-form-checkbox>
      </b-form-group>

      <!-- Toggle display -->
      <b-form-group class="mt-3" label="Toggle Display">
        <!-- Nest satisfied controls -->
        <b-form-checkbox
          id="nestSatisfiedRulesChecked"
          v-model="filters.nestSatisfiedRulesChecked"
          class="mb-1 unselectable"
          switch
          name="nestSatisfiedRulesChecked-fitler"
        >
          Nest Satisfied Controls
        </b-form-checkbox>

        <!-- Toggle STIG ID/SRG ID -->
        <b-form-checkbox
          id="showSRGIdChecked"
          v-model="filters.showSRGIdChecked"
          class="mb-1 unselectable"
          switch
          name="showSRGIdChecked-fitler"
        >
          Show SRG ID
        </b-form-checkbox>

        <!-- Toggle Sort by SRG ID -->
        <b-form-checkbox
          id="sortBySRGIdChecked"
          v-model="filters.sortBySRGIdChecked"
          class="mb-1 unselectable"
          switch
          name="sortBySRGIdChecked-fitler"
        >
          Sort by SRG ID
        </b-form-checkbox>
      </b-form-group>

      <hr class="mt-2 mb-2" />

      <!-- Currently opened controls -->
      <p class="mt-0 mb-1 d-flex justify-content-between align-items-center spacing-responsive">
        <strong>Open Controls</strong>
        <template v-if="openRuleIds.length > 0">
          <span class="clickable text-primary" @click="rulesDeselected(openRules)">
            <i class="mdi mdi-close clickable" />
            close all
          </span>
        </template>
      </p>
      <div v-if="openRules.length === 0">
        <em>No controls selected</em>
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
            <i
              class="mdi mdi-close closeRuleButton"
              aria-hidden="true"
              @click.stop="ruleDeselected(rule)"
            />
            <span v-if="filters.showSRGIdChecked">{{ rule.version }}</span>
            <span v-else>{{ formatRuleId(rule.rule_id) }}</span>
          </span>
          <span>
            <i
              v-if="rule.satisfies.length > 0"
              v-b-tooltip.hover
              class="mdi mdi-source-fork"
              title="Satisfies other"
              aria-hidden="true"
            />
            <i
              v-if="rule.satisfied_by.length > 0"
              v-b-tooltip.hover
              class="mdi mdi-content-copy"
              title="Satisfied by other"
              aria-hidden="true"
            />
            <i
              v-if="rule.review_requestor_id"
              v-b-tooltip.hover
              title="Review requested"
              class="mdi mdi-file-find"
              aria-hidden="true"
            />
            <i
              v-if="rule.locked"
              v-b-tooltip.hover
              title="Locked"
              class="mdi mdi-lock"
              aria-hidden="true"
            />
            <i
              v-if="rule.changes_requested"
              v-b-tooltip.hover
              title="Changes requested"
              class="mdi mdi-delta"
              aria-hidden="true"
            />
          </span>
        </div>
      </div>

      <hr class="mt-2 mb-2" />

      <!-- All project controls -->
      <p class="mt-0 mb-0 d-flex justify-content-between align-items-center spacing-responsive">
        <strong>All Controls</strong>
        <template v-if="!readOnly">
          <span v-b-modal.create-rule-modal class="text-primary clickable">
            <i v-b-modal.create-rule-modal class="mdi mdi-plus" /> add
          </span>
        </template>
      </p>

      <!-- New rule modal -->
      <NewRuleModalForm
        title="Create New Control"
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
            <span v-if="filters.showSRGIdChecked">
              {{ rule.version }}
            </span>
            <span v-else>
              {{ formatRuleId(rule.rule_id) }}
            </span>
          </span>
          <span>
            <i
              v-if="rule.satisfies.length > 0"
              v-b-tooltip.hover
              class="mdi mdi-source-fork"
              title="Satisfies other"
              aria-hidden="true"
            />

            <i
              v-if="rule.satisfied_by.length > 0"
              v-b-tooltip.hover
              class="mdi mdi-content-copy"
              title="Satisfied by other"
              aria-hidden="true"
            />
            <i
              v-if="rule.review_requestor_id"
              v-b-tooltip.hover
              title="Review requested"
              class="mdi mdi-file-find ml-1"
              aria-hidden="true"
            />
            <i
              v-if="rule.locked"
              v-b-tooltip.hover
              title="Locked"
              class="mdi mdi-lock ml-1"
              aria-hidden="true"
            />
            <i
              v-if="rule.changes_requested"
              v-b-tooltip.hover
              title="Changes requested"
              class="mdi mdi-delta ml-1"
              aria-hidden="true"
            />
          </span>
        </div>
        <div v-if="filters.nestSatisfiedRulesChecked && rule.satisfies.length > 0">
          <div
            v-for="satisfies in sortAlsoSatisfies(rule.satisfies)"
            :key="satisfies.id"
            :class="ruleRowClass(satisfies)"
            class="d-flex justify-content-between text-responsive"
            @click="ruleSelected(satisfies)"
          >
            <span>
              <i class="mdi mdi-chevron-right" />
              <span v-if="filters.showSRGIdChecked">
                {{ satisfies.version }}
              </span>
              <span v-else>
                {{ formatRuleId(satisfies.rule_id) }}
              </span>
            </span>
            <span>
              <i
                v-if="satisfies.review_requestor_id"
                v-b-tooltip.hover
                title="Review requested"
                class="mdi mdi-file-find ml-1"
                aria-hidden="true"
              />
              <i
                v-if="satisfies.locked"
                v-b-tooltip.hover
                title="Locked"
                class="mdi mdi-lock ml-1"
                aria-hidden="true"
              />
              <i
                v-if="satisfies.changes_requested"
                v-b-tooltip.hover
                title="Changes requested"
                class="mdi mdi-delta ml-1"
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
  },
  data: function () {
    return {
      rule_form_rule_id: "",
      sidebarOffset: 0, // How far the sidebar is from the top of the screen
      filters: {
        search: "",
        acFilterChecked: true, // Applicable - Configurable
        aimFilterChecked: true, // Applicable - Inherently Meets
        adnmFilterChecked: true, // Applicable - Does Not Meet
        naFilterChecked: true, // Not Applicable
        nydFilterChecked: true, // Not Yet Determined
        nurFilterChecked: true, // Not under review
        urFilterChecked: true, // Under review
        lckFilterChecked: true, // Locked
        nestSatisfiedRulesChecked: false, // Nests Satisfied Rules
        showSRGIdChecked: false, // Show SRG ID instead of STIG ID
        sortBySRGIdChecked: false, // Sort by SRG ID
      },
    };
  },
  computed: {
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
          JSON.stringify(this.filters)
        );
        localStorage.setItem(`showSRGIdChecked-${this.componentId}`, this.filters.showSRGIdChecked);
      },
      deep: true,
    },
  },
  mounted: function () {
    // Persist `filters` across page loads
    if (localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`)) {
      try {
        this.filters = JSON.parse(localStorage.getItem(`ruleNavigatorFilters-${this.componentId}`));
        this.$refs.ruleSearch.value = this.filters.search;
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

      return sortedRules.filter((rule) => {
        return (
          this.searchTextForRule(rule).includes(downcaseSearch) &&
          this.doesRuleHaveFilteredStatus(rule) &&
          this.doesRuleHaveFilteredReviewStatus(rule) &&
          (downcaseSearch.length > 0 || this.listSatisfiedRule(rule))
        );
      });
    },
    sortAlsoSatisfies: function (rules) {
      return [...rules].sort((a, b) => a.rule_id.localeCompare(b.rule_id));
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
      this.filters = {
        search: "",
        acFilterChecked: true, // Applicable - Configurable
        aimFilterChecked: true, // Applicable - Inherently Meets
        adnmFilterChecked: true, // Applicable - Does Not Meet
        naFilterChecked: true, // Not Applicable
        nydFilterChecked: true, // Not Yet Determined
        nurFilterChecked: true, // Not under review
        urFilterChecked: true, // Under review
        lckFilterChecked: true, // Locked
        nestSatisfiedRulesChecked: false, // Nests satisfied rules
        showSRGIdChecked: false, // Show SRG ID instead of STIG ID
        sortBySRGIdChecked: false, // Sort by SRG ID
      };
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

@media (min-width: 1200px) {
  .text-responsive {
    font-size: 1em;
    font-weight: 400;
  }
  .spacing-responsive {
    letter-spacing: 0.01em;
  }
}
</style>
