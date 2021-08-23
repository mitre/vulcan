<template>
  <div>
    <p class="mt-3 mb-0"><strong>Filter &amp; Search</strong></p>
    <div class="input-group">
      <input type="text" class="form-control" id="ruleSearch" placeholder="Search controls..." v-model="search">
    </div>

    <p class="mt-3 mb-0"><strong>Open Controls</strong></p>
    <div :class="ruleRowClass(rule)" @click="ruleSelected(rule)" :key="`open-${rule.id}`" v-for="rule in filteredOpenRules">
      <i @click.stop="removeOpenRule(rule.id)" class="mdi mdi-close closeRuleButton" aria-hidden="true"></i>
      {{rule.rule_id}}
      <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true"></i>
    </div>

    <p class="mt-3 mb-0"><strong>All Controls</strong></p>
    <div :class="ruleRowClass(rule)" @click="ruleSelected(rule)" :key="`rule-${rule.id}`" v-for="rule in filteredRules">
      {{rule.rule_id}}
      <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true"></i>
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
export default {
  name: 'RuleNavigator',
  props: {
    rules: {
      type: Array,
      required: true,
    },
    selectedRuleId: {
      type: Number,
      required: false,
    }
  },
  data: function() {
    return {
      // Tried using a `new Set()` for `openRuleIds`, but Vue would not react to changes.
      openRuleIds: [],
      search: ""
    }
  },
  computed: {
    // Filters down to all rules that apply to search & applied filters
    filteredRules: function() {
      return this.filterRules(this.rules).sort(this.sortById);
    },
    // Filters down to open rules that also apply to search & applied filters
    filteredOpenRules: function() {
      const openRules = this.rules.filter((rule) => this.openRuleIds.includes(rule.id)).sort(this.sortById);
      return this.filterRules(openRules)
    }
  },
  methods: {
    // Event handler for when a rule is selected
    ruleSelected: function(rule) {
      this.addOpenRule(rule.id);
      this.$emit('ruleSelected', rule.id);
    },
    // Adds a rule to the `openRules` array
    addOpenRule: function(ruleId) {
      if (this.openRuleIds.includes(ruleId)) {
        return;
      }
      this.openRuleIds.push(ruleId);
    },
    // Removes a rule from the `openRules` array
    removeOpenRule: function(ruleId) {
      const ruleIndex = this.openRuleIds.findIndex((id) => id == ruleId);
      // Guard from rule not found
      if (ruleIndex == -1) {
        return;
      }
      this.openRuleIds.splice(ruleIndex, 1)

      // Handle edge case where closed rule is the currently selected rule
      if (ruleId == this.selectedRuleId) {
        this.$emit('ruleSelected', null);
      }
    },
    // Helper to sort rules by ID
    sortById(rule1, rule2) {
      if (rule1.id < rule2.id) {
        return -1;
      }
      if (rule1.id > rule2.id) {
        return 1;
      }
      return 0;
    },
    // Dynamically set the class of each rule row
    ruleRowClass: function(rule) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.selectedRuleId == rule.id
      }
    },
    // Helper to filter & search a group of rules
    // PLACEHOLDER! searching by id - should be changed to title/name once implemented
    filterRules(rules) {
      let downcaseSearch = this.search.toLowerCase()
      return rules.filter(rule => rule.rule_id.toString().toLowerCase().includes(downcaseSearch));
    }
   }
}
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
  box-sizing: border-box
}

.closeRuleButton:hover {
  border: 1px solid red;
  border-radius: 0.2em;
}
</style>
