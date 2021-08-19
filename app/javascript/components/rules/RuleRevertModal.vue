<template>
  <div>
    <b-button 
      @click="showModal()"
      v-if="rule.locked == false && afterState && !isEmpty(afterState)"
      class="px-2 py-0"
      variant="warning"
    >
      Revert
    </b-button>

    <b-modal ref="revertModal" title="Revert Rule History" size="xl" ok-title="Revert" @ok="revertHistory()">
      <div class="row">
        <!-- CURRENT STATE -->
        <div class='col-6'>
          <p class="h3">Current State</p>
          
          <template v-if="history.action == 'destroy'">
            <p>Deleted</p>
          </template>

          <template v-else-if="history.auditable_type == 'Rule'">
            <RuleForm
              :rule="rule"
              :statuses="statuses"
              :severities="severities"
              :disabled="true"
            />
          </template>

          <template v-else-if="history.auditable_type == 'RuleDescription'">
            <RuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
            />
            <p v-else>Description does not exist.</p>
          </template>

          <template v-else-if="history.auditable_type == 'DisaRuleDescription'">
            <DisaRuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
            />
            <p v-else>Description does not exist.</p>
          </template>

          <template v-else-if="history.auditable_type == 'Check'">
            <CheckForm
              v-if="!isEmpty(currentState)"
              :check="currentState"
              :disabled="true"
            />
            <p v-else>Check does not exist.</p>
          </template>
        </div>

        <!-- STATE AFTER REVERT -->
        <div class='col-6'>
          <p class="h3">State After Revert</p>

          <p v-if="!afterState || isEmpty(afterState)">Could not determine resulting state.</p>
          
          <RuleForm
            v-else-if="history.auditable_type == 'Rule'"
            :rule="afterState"
            :statuses="statuses"
            :severities="severities"
            :disabled="true"
          />

          <RuleDescriptionForm
            v-else-if="history.auditable_type == 'RuleDescription'"
            :description="afterState"
            :disabled="true"
          />

          <DisaRuleDescriptionForm
            v-else-if="history.auditable_type == 'DisaRuleDescription'"
            :description="afterState"
            :disabled="true"
          />

          <CheckForm
            v-else-if="history.auditable_type == 'Check'"
            :check="afterState"
            :disabled="true"
          />

          <p v-else>Could not determine resulting state.</p>
        </div>
      </div>
    </b-modal>
  </div>
</template>

<script>
import axios from 'axios';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
export default {
  name: 'RuleRevertModal',
  mixins: [AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    history: {
      type: Object,
      required: true,
    },
    audited_change: {
      type: Object,
      required: false,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
  },
  computed: {
    modalId: function() {
      return `revert-modal-${this.history.id}-${this.audited_change["field"] || 'unknown'}`;
    },
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    currentState: function() {
      let dependentRecord = {}
      if (this.history.auditable_type == 'Rule') {
        dependentRecord = this.rule
      } else if (this.history.auditable_type == 'RuleDescription') {
        dependentRecord = this.rule.rule_descriptions_attributes.find(e => e.id == this.history.auditable_id)
      } else if (this.history.auditable_type == 'DisaRuleDescription') {
        dependentRecord = this.rule.disa_rule_descriptions_attributes.find(e => e.id == this.history.auditable_id)
      } else if (this.history.auditable_type == 'Check') {
        dependentRecord = this.rule.checks_attributes.find(e => e.id == this.history.auditable_id)
      }

      let curState = Object.assign({}, dependentRecord);
      if (this.isEmpty(curState)) {
        return {};
      }

      delete curState._destroy
      return curState;   
    },
    afterState: function() {
      // Get `currentState` and duplicate for modification
      let afterState = Object.assign({}, this.currentState);

      // Could not find the before state because the record was either
      // deleted or something went wrong and `{}` was returned by `currentState`
      if (this.isEmpty(afterState)) {
        // `this.audited_change == null` implies that action was a deletion
        // This means that `afterState` needs to be populated with the entirety of `history.audited_changes`
        if (this.audited_change == null) {
          for (let i = 0; i < this.history.audited_changes.length; i++) {
            afterState[this.history.audited_changes[i].field] = this.history.audited_changes[i].new_value;
          }
          return afterState;
        }
        return {};
      }

      // For and edit, just update the single `audited_change` from `currentState`
      afterState[this.audited_change.field] = this.audited_change.prev_value;
      return afterState;
    },
    changedFields: function() {
      if (this.audited_change == null) {
        return [];
      }
      return [this.audited_change.field];
    }
  },
  methods: {
    showModal: function() {
      this.$refs['revertModal'].show()
    },
    revertHistory: function() {
      let payload = {
        audit_id: this.history.id,
        field: this.audited_change.field
      };
      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.defaults.headers.common['Accept'] = 'application/json'
      axios.post(`/rules/${this.rule.id}/revert`, payload)
      .then(this.revertSuccess)
      .catch(this.alertOrNotifyResponse);
    },
    revertSuccess: function(response) {
      this.alertOrNotifyResponse(response);
      this.$emit('ruleUpdated', this.rule.id, 'all');
    },
    // Check if an object is empty
    isEmpty(o) {
      // Guard for the case where the object is null or undefined
      if (!o) {
        return true;
      }
      return Object.keys(o).length === 0;
    }
  }
}
</script>

<style scoped>
</style>
