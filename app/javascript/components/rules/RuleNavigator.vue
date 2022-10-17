<template>
  <div id="scrolling-sidebar" ref="sidebar" :style="sidebarStyle">
    <div class="mr-2">
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
          <strong>({{ ruleStatusCounts.ac }})</strong> Applicable - Configurable
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

      <!-- Show/hide duplicates -->
      <b-form-group class="mt-3" label="Filter by Duplicate Status">
        <b-form-checkbox
          id="showDuplicatesChecked"
          v-model="filters.showDuplicatesChecked"
          class="mb-1 unselectable"
          switch
          name="showDuplicatesChecked-fitler"
        >
          Show Duplicates
        </b-form-checkbox>
      </b-form-group>

      <!-- Find & Replace -->
      <FindAndReplace :component-id="componentId" :project-prefix="projectPrefix" :rules="rules" />

      <hr class="mt-2 mb-2" />

      <!-- Currently opened controls -->
      <p class="mt-0 mb-0">
        <strong>Open Controls</strong>
        <template v-if="openRuleIds.length > 0">
          <i
            class="text-primary mdi mdi-close clickable float-right"
            @click="rulesDeselected(openRules)"
          />
          <span class="text-primary float-right clickable" @click="rulesDeselected(openRules)">
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
          @click="ruleSelected(rule)"
        >
          <i
            class="mdi mdi-close closeRuleButton"
            aria-hidden="true"
            @click.stop="ruleDeselected(rule)"
          />
          {{ formatRuleId(rule.rule_id) }}
          <i
            v-if="rule.review_requestor_id"
            class="mdi mdi-file-find float-right"
            aria-hidden="true"
          />
          <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true" />
          <i v-if="rule.changes_requested" class="mdi mdi-delta float-right" aria-hidden="true" />
          <i
            v-if="rule.satisfied_by.length > 0"
            class="mdi mdi-content-copy float-right"
            aria-hidden="true"
          />
        </div>
      </div>

      <hr class="mt-2 mb-2" />

      <!-- All project controls -->
      <p class="mt-0 mb-0">
        <strong>All Controls</strong>
        <template v-if="!readOnly">
          <i v-b-modal.create-rule-modal class="text-primary mdi mdi-plus clickable float-right" />
          <span v-b-modal.create-rule-modal class="text-primary float-right clickable">add </span>
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
      <div
        v-for="rule in filteredRules"
        :key="`rule-${rule.id}`"
        :class="ruleRowClass(rule)"
        @click="ruleSelected(rule)"
      >
        {{ formatRuleId(rule.rule_id) }}
        <i
          v-if="rule.review_requestor_id"
          class="mdi mdi-file-find float-right"
          aria-hidden="true"
        />
        <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true" />
        <i v-if="rule.changes_requested" class="mdi mdi-delta float-right" aria-hidden="true" />
        <i
          v-if="rule.satisfied_by.length > 0"
          class="mdi mdi-content-copy float-right"
          aria-hidden="true"
        />
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
        showDuplicatesChecked: false, // Show duplicates
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

      // review counts
      let nurCount = 0;
      let urCount = 0;
      let lckCount = 0;

      for (var i = 0; i < this.rules.length; i++) {
        const status = this.rules[i].status;
        // Status counts
        if (status == "Applicable - Configurable") {
          acCount += 1;
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
        (this.filters.acFilterChecked && rule.status == "Applicable - Configurable") ||
        (this.filters.aimFilterChecked && rule.status == "Applicable - Inherently Meets") ||
        (this.filters.adnmFilterChecked && rule.status == "Applicable - Does Not Meet") ||
        (this.filters.naFilterChecked && rule.status == "Not Applicable") ||
        (this.filters.nydFilterChecked && rule.status == "Not Yet Determined")
      );
    },
    doesRuleHaveFilteredReviewStatus: function (rule) {
      return (
        (this.filters.nurFilterChecked &&
          rule.locked == false &&
          rule.review_requestor_id == null) ||
        (this.filters.urFilterChecked &&
          rule.locked == false &&
          rule.review_requestor_id != null) ||
        (this.filters.lckFilterChecked && rule.locked == true)
      );
    },
    isDuplicate: function (rule) {
      return this.filters.showDuplicatesChecked || rule.satisfied_by.length === 0;
    },
    // Helper to filter & search a group of rules
    filterRules: function (rules) {
      let downcaseSearch = this.filters.search.toLowerCase();
      return rules.filter((rule) => {
        return (
          this.searchTextForRule(rule).includes(downcaseSearch) &&
          this.doesRuleHaveFilteredStatus(rule) &&
          this.doesRuleHaveFilteredReviewStatus(rule) &&
          this.isDuplicate(rule)
        );
      });
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
        showDuplicatesChecked: false, // Show duplicates
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
</style>
