<template>
  <div>
    <p class="mt-3 mb-0"><strong>Filter &amp; Search</strong></p>
    <div class="input-group">
      <input
        id="ruleSearch"
        v-model="search"
        type="text"
        class="form-control"
        placeholder="Search controls..."
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
      :forDuplicate="false"
      :idPrefix="'create'"
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
import NewRuleModalForm from './forms/NewRuleModalForm.vue'
export default {
  name: "RuleNavigator",
  components: { NewRuleModalForm },
  props: {
    projectPermissions: {
      type: String,
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
      return this.filterRules(this.rules).sort(this.sortById);
    },
    // Filters down to open rules that also apply to search & applied filters
    filteredOpenRules: function () {
      const openRules = this.rules
        .filter((rule) => this.openRuleIds.includes(rule.id))
        .sort(this.sortById);
      return this.filterRules(openRules);
    },
  },
  methods: {
    // Event handler for when a rule is selected
    ruleSelected: function (rule) {
      this.$emit("ruleSelected", rule.id);
    },
    ruleDeselected: function (rule) {
      this.$emit("ruleDeselected", rule.id);
    },
    // Helper to sort rules by ID
    sortById(rule1, rule2) {
      if (this.formatRuleId(rule1.id).toLowerCase() < this.formatRuleId(rule2.id).toLowerCase()) {
        return -1;
      }
      if (this.formatRuleId(rule1.id).toLowerCase() > this.formatRuleId(rule2.id).toLowerCase()) {
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
    filterRules(rules) {
      let downcaseSearch = this.search.toLowerCase();
      return rules.filter((rule) =>
        this.formatRuleId(rule.id).toString().toLowerCase().includes(downcaseSearch)
      );
    },
    formatRuleId(id) {
      return `${this.projectPrefix}-${id}`;
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
