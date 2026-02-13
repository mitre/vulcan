<template>
  <div>
    <!-- Also Satisfies section (shown when not satisfied by another rule) -->
    <div v-if="rule.satisfied_by && rule.satisfied_by.length === 0">
      <div class="d-flex justify-content-between align-items-center mb-2">
        <div>
          <strong>Also Satisfies</strong>
          <b-badge v-if="rule.satisfies" pill variant="info" class="ml-1">{{
            rule.satisfies.length
          }}</b-badge>
        </div>
        <b-button
          v-if="rule.status === 'Applicable - Configurable'"
          v-b-modal.also-satisfies-modal
          size="sm"
          variant="outline-primary"
          :disabled="readOnly"
        >
          <b-icon icon="plus" /> Add
        </b-button>
      </div>
      <p v-if="readOnly" class="text-muted small mb-2">
        <em>Edit mode required to modify</em>
      </p>

      <div
        v-for="satisfies in rule.satisfies"
        :key="satisfies.id"
        :class="ruleRowClass(satisfies)"
        class="d-flex justify-content-between align-items-center"
      >
        <span
          v-b-tooltip.hover
          :title="satisfies.srg_rule && satisfies.srg_rule.version"
          class="clickable"
          @click="ruleSelected(satisfies)"
        >
          {{ truncateId(satisfies.srg_rule && satisfies.srg_rule.version) }}
        </span>
        <b-button
          v-b-modal.unmark-satisfies-modal
          size="sm"
          variant="outline-danger"
          class="ml-2"
          :disabled="readOnly"
          @click="satisfies_rule = satisfies"
        >
          Remove
        </b-button>
      </div>

      <p v-if="rule.satisfies.length === 0" class="text-muted small">
        No other controls satisfied by this one.
      </p>

      <b-modal
        id="unmark-satisfies-modal"
        title="Remove Satisfaction Relationship"
        centered
        @ok="$root.$emit('removeSatisfied:rule', satisfies_rule.id, rule.id)"
      >
        <p>
          Are you sure this control no longer satisfies
          <strong
            v-b-tooltip.hover
            :title="satisfies_rule && satisfies_rule.srg_rule && satisfies_rule.srg_rule.version"
          >
            {{ truncateId(satisfies_rule && satisfies_rule.srg_rule && satisfies_rule.srg_rule.version) }}
          </strong
          >?
        </p>
        <template #modal-footer="{ cancel, ok }">
          <b-button @click="cancel()">Cancel</b-button>
          <b-button variant="danger" @click="ok()">Remove</b-button>
        </template>
      </b-modal>
    </div>

    <!-- Satisfied By section (shown when this rule is satisfied by another) -->
    <div v-if="rule.satisfied_by && rule.satisfied_by.length > 0">
      <div class="mb-2">
        <strong>Satisfied By</strong>
        <b-badge pill variant="info" class="ml-1">{{ rule.satisfied_by.length }}</b-badge>
      </div>
      <p v-if="readOnly" class="text-muted small mb-2">
        <em>Edit mode required to modify</em>
      </p>

      <div
        v-for="satisfied_by in rule.satisfied_by"
        :key="satisfied_by.id"
        :class="ruleRowClass(satisfied_by)"
        class="d-flex justify-content-between align-items-center"
      >
        <span
          v-b-tooltip.hover
          :title="satisfied_by.srg_rule && satisfied_by.srg_rule.version"
          class="clickable"
          @click="ruleSelected(satisfied_by)"
        >
          {{ truncateId(satisfied_by.srg_rule && satisfied_by.srg_rule.version) }}
        </span>
        <b-button
          v-b-modal.unmark-satisfied-by-modal
          size="sm"
          variant="outline-danger"
          class="ml-2"
          :disabled="readOnly"
          @click="satisfied_by_rule = satisfied_by"
        >
          Remove
        </b-button>
      </div>

      <b-modal
        id="unmark-satisfied-by-modal"
        title="Remove Satisfaction Relationship"
        centered
        @ok="$root.$emit('removeSatisfied:rule', rule.id, satisfied_by_rule.id)"
      >
        <p>
          Are you sure this control is no longer satisfied by
          <strong
            v-b-tooltip.hover
            :title="satisfied_by_rule && satisfied_by_rule.srg_rule && satisfied_by_rule.srg_rule.version"
          >
            {{ truncateId(satisfied_by_rule && satisfied_by_rule.srg_rule && satisfied_by_rule.srg_rule.version) }}
          </strong
          >?
        </p>
        <template #modal-footer="{ cancel, ok }">
          <b-button @click="cancel()">Cancel</b-button>
          <b-button variant="danger" @click="ok()">Remove</b-button>
        </template>
      </b-modal>
    </div>
  </div>
</template>

<script>
import { truncateId } from "../../utils/idFormatter";

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
      satisfies_rule: null,
      satisfied_by_rule: null,
      truncateId, // Expose utility for template
    };
  },
  methods: {
    ruleSelected: function (rule) {
      if (!rule.histories) {
        this.$root.$emit("refresh:rule", rule.id);
      }
      this.$emit("ruleSelected", rule.id);
    },
    ruleRowClass: function (rule) {
      return {
        ruleRow: true,
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

/* Disabled button styling */
.btn:disabled,
.btn.disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
</style>
