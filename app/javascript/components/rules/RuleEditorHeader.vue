<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <h2>{{rule.rule_id}}</h2>

      <!-- Rule info -->
      <!-- <p>Based on ...</p> -->
      <p v-if="rule.histories.length> 0">Last updated on {{friendlyDateTime(rule.updated_at)}} by {{lastEditor}}</p>
      <p v-else>Created on {{friendlyDateTime(rule.created_at)}}</p>

      <!-- Action Buttons -->
      <!-- Disable and enable save & delete buttons based on locked state of rule -->
      <template v-if="rule.locked">
        <span class="d-inline-block" v-b-tooltip.hover title="Control is locked.">
          <b-button variant="success" disabled>Save Control</b-button>
        </span>
        <span class="d-inline-block" v-b-tooltip.hover title="Control is locked.">
          <b-button variant="danger" disabled>Delete Control</b-button>
        </span>
      </template>
      <template v-else>
        <b-button @click="saveRule()" variant="success">Save Control</b-button>
        <b-button variant="danger">Delete Control</b-button>
        <!-- <b-button>Duplicate Control</b-button> -->
      </template>
      <b-button @click="manageLock(false)" v-if="rule.locked" variant="warning">Unlock Control</b-button>
      <b-button @click="manageLock(true)" v-else variant="warning">Lock Control</b-button>
    </div>
  </div>
</template>

<script>
import axios from 'axios';
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
export default {
  name: 'RuleEditorHeader',
  mixins: [DateFormatMixinVue, AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    }
  },
  computed: {
    // Authenticity Token for forms
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
    lastEditor: function() {
      const histories = this.rule.histories;
      if (histories.length > 0) {
        return histories[histories.length - 1].name
      }
      return 'Unknown User'
    }
  },
  methods: {
    manageLock: function(desiredLockState) {
      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.defaults.headers.common['Accept'] = 'application/json'
      axios.post(`/rules/${this.rule.id}/manage_lock`, {
        locked: desiredLockState
      })
      .then(this.manageLockSuccess)
      .catch(this.alertOrNotifyResponse);
    },
    manageLockSuccess: function(response) {
      this.alertOrNotifyResponse(response);
      this.$emit('ruleUpdated', this.rule.id, 'all');
    },
    saveRule() {
      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.defaults.headers.common['Accept'] = 'application/json'
      axios.put(`/rules/${this.rule.id}`, this.rule)
      .then(this.saveRuleSuccess)
      .catch(this.alertOrNotifyResponse);
    },
    saveRuleSuccess: function(response) {
      this.alertOrNotifyResponse(response);
      this.$emit('ruleUpdated', this.rule.id, 'all');
    },
  }
}
</script>

<style scoped>
</style>
