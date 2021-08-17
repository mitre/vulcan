<template>
  <div>
    <!-- Collapsable header -->
    <div @click="showHistories = !showHistories" class="clickable">
      <h2 class="m-0 d-inline-block">Histories</h2>
      <b-badge pill class="superVerticalAlign">{{rule.histories.length}}</b-badge>

      <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showHistories"></i>
      <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showHistories"></i>
    </div>

    <!-- All histories -->
    <b-collapse id="collapse-histories" v-model="showHistories">
      <div :key="history.id" v-for="history in rule.histories">
        <p class="ml-2 mb-0 mt-2"><strong>{{history.name}}</strong></p>
        <p class="ml-2 mb-0"><small>{{friendlyDateTime(history.created_at)}}</small></p>
        <!-- Edit on the Rule itself -->
        <template v-if="history.auditable_type == 'Rule'">
          <!-- Edit on the rule itself -->
          <template v-if="history.action == 'update'">
            <div class="ml-3 mb-3" :key="audited_change.field" v-for="audited_change in history.audited_changes">
              <p class="mb-1">
                {{audited_change.field}}
                was changed from
                <span class="historyChangeText">{{audited_change.prev_value == null ? 'no value' : audited_change.prev_value}}</span>
                to
                <span class="historyChangeText">{{audited_change.new_value}}</span>
              </p>
              <b-button v-if="rule.locked == false" class="px-2 py-0" variant="warning" @click="revertHistory(history, audited_change.field)">Revert</b-button>
            </div>
          </template>

          <!-- Create on the rule itself -->
          <template v-if="history.action == 'create'">
            <p class="ml-3 mb-3">Rule was created.</p>
          </template>
        </template>

        <!-- Edit or Deletion on one of the Rule's associated records-->
        <template v-else>
           <!-- Create on the rule itself -->
          <template v-if="history.action == 'create'">
            <p class="ml-3 mb-3">{{history.auditable_type}} with ID {{history.auditable_id}} was created.</p>
          </template>

          <!-- Edit on the associated record -->
          <template v-if="history.action == 'update'">
            <div class="ml-3 mb-3" :key="audited_change.field" v-for="audited_change in history.audited_changes">
              <p class="mb-1">{{history.auditable_type}} with ID {{history.auditable_id}} was updated.</p>
              <p class="mb-1">
                {{audited_change.field}}
                was changed from
                <span class="historyChangeText">{{audited_change.prev_value == null ? 'no value' : audited_change.prev_value}}</span>
                to
                <span class="historyChangeText">{{audited_change.new_value}}</span>
              </p>
              <b-button v-if="rule.locked == false" class="px-2 py-0" variant="warning" @click="revertHistory(history, audited_change.field)">Revert</b-button>
            </div>
          </template>

          <!-- Deletion on the associated record -->
          <template v-if="history.action == 'destroy'">
            <p class="ml-3 mb-1">{{history.auditable_type}} with ID {{history.auditable_id}} was deleted.</p>
            <div class="ml-3 mb-1" :key="audited_change.field" v-for="audited_change in history.audited_changes">
              <p class="mb-1">
                {{audited_change.field}}:
                <span class="historyChangeText">{{audited_change.new_value}}</span>
              </p>
            </div>
            <b-button v-if="rule.locked == false" class="px-2 py-0 ml-3 mb-3" variant="warning" @click="revertHistory(history, null)">Revert</b-button>
          </template>
        </template>

        
      </div>
    </b-collapse>
  </div>
</template>

<script>
import axios from 'axios';
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
export default {
  name: 'RuleHistories',
  mixins: [DateFormatMixinVue, AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    }
  },
  data: function() {
    return {
      showHistories: false
    }
  },
  computed: {
    // Authenticity Token for forms
    authenticityToken: function() {
      return document.querySelector("meta[name='csrf-token']").getAttribute("content");
    },
  },
  methods: {
    revertHistory: function(history, field) {
      let payload = {
        audit_id: history.id,
        field: field
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
  }
}
</script>

<style scoped>
.historyChangeText {
  background: rgb(0, 0, 0, 0.1);
  border: 1px solid rgb(0, 0, 0, 0);
  border-radius: 0.25em;
}
</style>
