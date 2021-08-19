<template>
  <div>
    <b-button @click="showModal()" v-if="rule.locked == false" class="px-2 py-0" variant="warning">Revert</b-button>

    <b-modal ref="revertModal" title="Revert Rule History" size="xl" ok-title="Revert" @ok="revertHistory()">
      <div class="row">
        <!-- CURRENT STATE -->
        <div class='col-6'>
          <p class="h3">Current State</p>
          <p v-if="currentState == null">N/A</p>
          <template v-if="currentState != null">
            <div :key="key" v-for="(value, key) in currentState">
              <p class="mb-0"><strong>{{key}}</strong></p>
              <p>{{value || '*NO VALUE*'}}</p>
            </div>
          </template>
        </div>

        <!-- STATE AFTER REVERT -->
        <div class='col-6'>
          <p class="h3">State After Revert</p>
          <template v-if="afterState != null">
            <div :key="key" v-for="(value, key) in afterState">
              <p class="mb-0"><strong>{{key}}</strong></p>
              <p :class="changedFieldClass(key)">{{value || '*NO VALUE*'}}</p>
            </div>
          </template>
        </div>
        Changed Fields: {{changedFields}}
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
    }
  },
  computed: {
    modalId: function() {
      return `revert-modal-${this.history.id}-${this.audited_change["field"] || 'unknown'}`;
    },
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    currentState: function() {
      // Would expect this to be null for a deletion record
      if (this.audited_change == null) {
        return null;
      }
      console.log('1')

      let curState = {};

      // Check if the change was on the record itself
      // If so, we really only need to show the specific field that changed
      if (this.history.auditable_type == 'Rule') {
        console.log('1.1')
        curState[this.audited_change.field] = this.rule[this.audited_change.field]
        return curState;
      }
      console.log('1.2')

      // The change was on a dependent record & the change needs to be
      // contextualized for that specific record
      let contextualizedRecord = null;
      if (this.history.auditable_type == 'RuleDescription') {
        console.log('2.1')
        contextualizedRecord = this.rule.rule_descriptions_attributes.find(e => e.id == this.history.auditable_id)
      } else if (this.history.auditable_type == 'DisaRuleDescription') {
        console.log('2.2')
        contextualizedRecord = this.rule.disa_rule_descriptions_attributes.find(e => e.id == this.history.auditable_id)
      } else if (this.history.auditable_type == 'Check') {
        console.log('2.3')
        contextualizedRecord = this.rule.checks_attributes.find(e => e.id == this.history.auditable_id)
      } else {
        console.log('2.4')
        // Guard if the record was not found (e.g. record was deleted post-edit)
        return null;
      }
      console.log('3')
      let clonedRecord = Object.assign({}, contextualizedRecord)
      delete clonedRecord.id
      delete clonedRecord.rule_id
      delete clonedRecord._destroy
      delete clonedRecord.updated_at
      delete clonedRecord.created_at
      console.log('4')

      return clonedRecord;      
    },
    afterState: function() {
      // Would expect this to be null for a deletion record
      if (this.audited_change == null) {
        return 'todo';
      }

      let afterState = this.currentState;
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
    changedFieldClass: function(key) {
      if (this.changedFields.includes(key)) {
        return 'text-success';
      }
      return '';
    }
  }
}
</script>

<style scoped>
</style>
