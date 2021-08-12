<template>
  <div>
    <p class="ruleNavigatorSection"><strong>Filter &amp; Search</strong></p>
    <div class="input-group">
      <input type="text" class="form-rule" id="ruleSearch" placeholder="Search controls..." v-model="search">
    </div>

    <p class="ruleNavigatorSection"><strong>Open Controls</strong></p>
    <div :class="ruleRowClass(rule)" @click="ruleSelected(rule)" :key="'open-' + rule.id" v-for="rule in filteredOpenRules">
      <i @click.stop="removeOpenRule(rule)" class="mdi mdi-close closeRuleButton" aria-hidden="true"></i>
      {{rule.id}}
    </div>

    <p class="ruleNavigatorSection"><strong>All Controls</strong></p>
    <div :class="ruleRowClass(rule)" @click="ruleSelected(rule)" :key="'rule-' + rule.id" v-for="rule in filteredRules">
      {{rule.id}}
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
    selectedRule: {
      type: Object,
      required: false,
    }
  },
  data: function() {
    return {
      openRules: [],
      search: ""
    }
  },
  computed: {
    filteredRules: function() {
      return this.filterRules(this.rules).sort(this.sortById);
    },
    filteredOpenRules: function() {
      return this.filterRules(this.openRules);
    },
  },
  methods: {
    // Event handler for when a rule is selected
    ruleSelected: function(rule) {
      this.addOpenRule(rule);
      this.$emit('ruleSelected', rule);
    },
    // Adds a rule to the `openRules` array
    addOpenRule: function(rule) {
      // Guard against duplicate
      for (let i = 0; i < this.openRules.length; i++) {
        if (this.openRules[i].id == rule.id) {
          return;
        }
      }
      // Push to array and re-sort
      this.openRules.push(rule);
      this.openRules.sort(this.sortById);
    },
    // Removes a rule from the `openRules` array
    removeOpenRule: function(rule) {
      const found = this.openRules.findIndex(c => c.id == rule.id);
      if (found != -1) {
        this.openRules.splice(found, 1);

        // Handle the case where the close rule was the selected rule
        if (rule.id == this.selectedRule?.id) {
          this.$emit('ruleSelected', null);
        }
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
        selectedRuleRow: this.selectedRule?.id == rule.id
      }
    },
    // Helper to filter & search a group of rules
    // PLACEHOLDER! searching by id - should be changed to title/name once implemented
    filterRules(rules) {
      let downcaseSearch = this.search.toLowerCase()
      return rules.filter(user => user.id.toString().toLowerCase().includes(downcaseSearch));
    }
   }
}
</script>

<style scoped>
.ruleRow {
  cursor: pointer;
  padding: 0.25em;
}
.selectedRuleRow {
  background: rgba(66, 50, 50, 0.09);
}
.ruleRow:hover {
  background: rgb(0, 0, 0, 0.12);
}
.ruleNavigatorSection {
  margin: 1em 0em 0em 0em;
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
