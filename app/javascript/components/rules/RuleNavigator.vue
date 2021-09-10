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
        @click.stop="removeOpenRule(rule.id)"
      />
      {{ rule.rule_id }}
      <i v-if="rule.locked" class="mdi mdi-lock float-right" aria-hidden="true" />
    </div>

    <p class="mt-3 mb-0">
      <strong>All Controls</strong>
      <i v-b-modal.create-rule-modal class="mdi mdi-plus-thick clickable float-right" />
    </p>

    <!-- New rule modal -->
    <b-modal
      id="create-rule-modal"
      ref="modal"
      title="Create New Control"
      centered
      @show="rule_form_rule_id = ''"
      @shown="$refs.newRuleIdInput.focus()"
      @ok="
        $root.$emit('create:rule', rule_form_rule_id, (response) =>
          ruleSelected(response.data.data)
        )
      "
    >
      <form ref="form" @submit.stop.prevent="handleSubmit">
        <b-form-group
          id="rule-id-input-group"
          label="Control ID"
          label-for="rule-id-input"
          description="This must be unique for the project."
        >
          <b-form-input
            id="rule-id-input"
            ref="newRuleIdInput"
            v-model="rule_form_rule_id"
            placeholder="Enter control ID"
            autocomplete="off"
            required
          />
        </b-form-group>
      </form>
    </b-modal>

    <!-- All rules list -->
    <div
      v-for="rule in filteredRules"
      :key="`rule-${rule.id}`"
      :class="ruleRowClass(rule)"
      @click="ruleSelected(rule)"
    >
      {{ rule.rule_id }}
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
export default {
  name: "RuleNavigator",
  props: {
    rules: {
      type: Array,
      required: true,
    },
    selectedRuleId: {
      type: Number,
      required: false,
    },
  },
  data: function () {
    return {
      // Tried using a `new Set()` for `openRuleIds`, but Vue would not react to changes.
      openRuleIds: [],
      search: "",
      rule_form_rule_id: "",
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
  watch: {
    openRuleIds: function (_) {
      localStorage.setItem("openRuleIds", JSON.stringify(this.openRuleIds));
    },
  },
  mounted: function () {
    // Persist `openRuleIds` across page loads
    if (localStorage.getItem("openRuleIds")) {
      try {
        this.openRuleIds = JSON.parse(localStorage.getItem("openRuleIds"));
      } catch (e) {
        localStorage.removeItem("openRuleIds");
      }
    }
  },
  methods: {
    // Event handler for when a rule is selected
    ruleSelected: function (rule) {
      this.addOpenRule(rule.id);
      this.$emit("ruleSelected", rule.id);
    },
    // Adds a rule to the `openRules` array
    addOpenRule: function (ruleId) {
      if (this.openRuleIds.includes(ruleId)) {
        return;
      }
      this.openRuleIds.push(ruleId);
    },
    // Removes a rule from the `openRules` array
    removeOpenRule: function (ruleId) {
      const ruleIndex = this.openRuleIds.findIndex((id) => id == ruleId);
      // Guard from rule not found
      if (ruleIndex == -1) {
        return;
      }
      this.openRuleIds.splice(ruleIndex, 1);

      // Handle edge case where closed rule is the currently selected rule
      if (ruleId == this.selectedRuleId) {
        this.$emit("ruleSelected", null);
      }
    },
    // Helper to sort rules by ID
    sortById(rule1, rule2) {
      if (rule1.rule_id.toLowerCase() < rule2.rule_id.toLowerCase()) {
        return -1;
      }
      if (rule1.rule_id.toLowerCase() > rule2.rule_id.toLowerCase()) {
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
      return rules.filter((rule) => rule.rule_id.toString().toLowerCase().includes(downcaseSearch));
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
