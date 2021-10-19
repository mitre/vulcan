<template>
  <div>
    <p class="mt-3 mb-0"><strong>Filter &amp; Search</strong></p>
    <div class="input-group">
      <input
        id="ruleSearch"
        type="text"
        class="form-control"
        placeholder="Search controls..."
        @input="searchUpdated($event.target.value)"
      />
    </div>

    <p class="mt-3 mb-0"><strong>Open Controls</strong></p>
    <div
      v-for="rule in filteredOpenRules"
      :key="`open-${rule.id}`"
      :class="ruleRowClass(rule)"
      @click="ruleSelected(rule)"
    >
      <i
        class="mdi mdi-close closeRuleButton"
        aria-hidden="true"
        @click.stop="ruleDeselected(rule)"
      />
      {{ formatRuleId(rule.id) }}
      <i v-if="rule.review_requestor_id" class="mdi mdi-file-find float-right" aria-hidden="true" />
      <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true" />
    </div>

    <p class="mt-3 mb-0">
      <strong>All Controls</strong>
      <template v-if="!readOnly">
        <i v-b-modal.create-rule-modal class="mdi mdi-plus-thick clickable float-right" />
        <strong v-b-modal.create-rule-modal class="float-right clickable">add </strong>
      </template>
    </p>

    <!-- New rule modal -->
    <NewRuleModalForm
      :title="'Create New Control'"
      :for-duplicate="false"
      :id-prefix="'create'"
      @ruleSelected="ruleSelected($event)"
    />

    <!-- All rules list -->
    <div
      v-for="rule in filteredRules"
      :key="`rule-${rule.id}`"
      :class="ruleRowClass(rule)"
      @click="ruleSelected(rule)"
    >
      {{ formatRuleId(rule.id) }}
      <i v-if="rule.review_requestor_id" class="mdi mdi-file-find float-right" aria-hidden="true" />
      <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true" />
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
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";
export default {
  name: "RuleNavigator",
  components: { NewRuleModalForm },
  props: {
    effectivePermissions: {
      type: String,
      default: "",
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
      search: "",
    };
  },
  computed: {
    // Filters down to all rules that apply to search & applied filters
    filteredRules: function () {
      return this.filterRules(this.rules).sort(this.compareRules);
    },
    // Filters down to open rules that also apply to search & applied filters
    filteredOpenRules: function () {
      const openRules = this.rules
        .filter((rule) => this.openRuleIds.includes(rule.id))
        .sort(this.compareRules);
      return this.filterRules(openRules);
    },
  },
  methods: {
    searchUpdated: _.debounce(function (newSearch) {
      this.search = newSearch;
    }, 500),
    // Event handler for when a rule is selected
    ruleSelected: function (rule) {
      this.$emit("ruleSelected", rule.id);
    },
    ruleDeselected: function (rule) {
      this.$emit("ruleDeselected", rule.id);
    },
    // Helper to sort rules by ID
    compareRules(rule1, rule2) {
      let rule1Comp = rule1.id;
      let rule2Comp = rule2.id;
      if (rule1Comp < rule2Comp) {
        return -1;
      }
      if (rule1Comp > rule2Comp) {
        return 1;
      }
      return 0;
    },
    // Dynamically set the class of each rule row
    ruleRowClass: function (rule) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.selectedRuleId == rule.id,
      };
    },
    // Helper to filter & search a group of rules
    // PLACEHOLDER! searching by id - should be changed to title/name once implemented
    filterRules: function (rules) {
      let downcaseSearch = this.search.toLowerCase();
      return rules.filter((rule) => this.searchTextForRule(rule).includes(downcaseSearch));
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
        "artifact_description",
        "fix_id",
        "fixtext",
        "fixtext_fixref",
        "ident",
        "ident_system",
        "rule_id",
        "rule_severity",
        "rule_weight",
        "status",
        "title",
        "vendor_comments",
        "version",
      ];
      const checkDescriptionSearchAttrs = [
        "content",
        "content_ref_href",
        "content_ref_name",
        "system",
      ];
      const disaDescriptionSearchAttrs = [
        "false_negatives",
        "false_positives",
        "ia_controls",
        "mitigation_controls",
        "mitigations",
        "potential_impacts",
        "responsibility",
        "security_override_guidance",
        "third_party_tools",
        "vuln_discussion",
      ];
      // Start with the rule ID as searchable
      let searchText = this.formatRuleId(rule.id);
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
</style>
