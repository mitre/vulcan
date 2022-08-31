<template>
  <div>
    <div v-if="rule.satisfies && rule.satisfies.length > 0">
      <!-- Collapsable header -->
      <div class="clickable" @click="showAlsoSatisfies = !showAlsoSatisfies">
        <h2 class="m-0 d-inline-block">Also Satisfies</h2>
        <b-badge v-if="rule.satisfies" pill class="ml-1 superVerticalAlign">{{
          rule.satisfies.length
        }}</b-badge>

        <i v-if="showAlsoSatisfies" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
        <i v-if="!showAlsoSatisfies" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
      </div>

      <!-- All rules also satisfied -->
      <b-collapse id="collapse-satisfies" v-model="showAlsoSatisfies">
        <div
          v-for="satisfies in rule.satisfies"
          :key="satisfies.id"
          :class="ruleRowClass(satisfies)"
        >
          <i
            v-if="!readOnly"
            v-b-modal.unmark-satisfies-modal
            class="mdi mdi-close closeRuleButton"
            aria-hidden="true"
            @click="satisfies_rule = satisfies"
          />
          <span @click="ruleSelected(satisfies)">
            {{ formatRuleForDisplay(satisfies) }}
          </span>
        </div>
      </b-collapse>

      <b-modal
        id="unmark-satisfies-modal"
        title="Unmark as Duplicate"
        centered
        @ok="$root.$emit('unmarkDuplicate:rule', satisfies_rule.id, rule.id)"
      >
        <p>
          Are you sure you want to unmark {{ formatRuleForDisplay(satisfies_rule) }} as a duplicate
          of this control?
        </p>
        <template #modal-footer="{ cancel, ok }">
          <!-- Emulate built in modal footer ok and cancel button actions -->
          <b-button @click="cancel()"> Cancel </b-button>
          <b-button variant="info" @click="ok()"> OK </b-button>
        </template>
      </b-modal>
    </div>

    <div v-if="rule.satisfied_by && rule.satisfied_by.length > 0">
      <!-- Collapsable header -->
      <div class="clickable" @click="showSatisfiedBy = !showSatisfiedBy">
        <h2 class="m-0 d-inline-block">Satisfied By</h2>
        <b-badge v-if="rule.satisfied_by" pill class="ml-1 superVerticalAlign">{{
          rule.satisfied_by.length
        }}</b-badge>

        <i v-if="showSatisfiedBy" class="mdi mdi-menu-down superVerticalAlign collapsableArrow" />
        <i v-if="!showSatisfiedBy" class="mdi mdi-menu-up superVerticalAlign collapsableArrow" />
      </div>

      <!-- All rules also satisfied -->
      <b-collapse id="collapse-satisfied-by" v-model="showSatisfiedBy">
        <div
          v-for="satisfied_by in rule.satisfied_by"
          :key="satisfied_by.id"
          :class="ruleRowClass(satisfied_by)"
        >
          <i
            v-if="!readOnly"
            v-b-modal.unmark-satisfied-by-modal
            class="mdi mdi-close closeRuleButton"
            aria-hidden="true"
            @click="satisfied_by_rule = satisfied_by"
          />
          <span @click="ruleSelected(satisfied_by)">
            {{ formatRuleForDisplay(satisfied_by) }}
          </span>
        </div>
      </b-collapse>

      <b-modal
        id="unmark-satisfied-by-modal"
        title="Unmark as Duplicate"
        centered
        @ok="$root.$emit('unmarkDuplicate:rule', rule.id, satisfied_by_rule.id)"
      >
        <p>
          Are you sure you want to unmark this control as a duplicate of
          {{ formatRuleForDisplay(satisfied_by_rule) }}
        </p>
        <template #modal-footer="{ cancel, ok }">
          <!-- Emulate built in modal footer ok and cancel button actions -->
          <b-button @click="cancel()"> Cancel </b-button>
          <b-button variant="info" @click="ok()"> OK </b-button>
        </template>
      </b-modal>
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
// <RuleSatisfactions @ruleSelected="handleRuleSelected($event)" ... />
//
export default {
  name: "RuleSatisfactions",
  props: {
    component: {
      type: Object,
      required: true,
    },
    rule: {
      type: Object,
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
    readOnly: {
      type: Boolean,
      required: false,
    },
  },
  data: function () {
    return {
      showAlsoSatisfies: true,
      showSatisfiedBy: true,
      satisfies_rule: null,
      satisfied_by_rule: null,
    };
  },
  methods: {
    // Event handler for when a rule is selected
    ruleSelected: function (rule) {
      if (!rule.histories) {
        this.$root.$emit("refresh:rule", rule.id);
      }
      this.$emit("ruleSelected", rule.id);
    },
    formatRuleForDisplay: function (rule) {
      return `${this.projectPrefix}-${rule?.rule_id} // ${rule?.version}`;
    },
    // Dynamically set the class of each rule row
    ruleRowClass: function (rule) {
      return {
        ruleRow: true,
        clickable: true,
        selectedRuleRow: this.selectedRuleId == rule.id,
      };
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
