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
            <a class="ml-3 text-info clickable" v-b-toggle="`history-collapse-${history.id}`">{{friendlyAuditableType(history.auditable_type)}} Updated...</a>
            <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
              <div class="ml-3 mb-3" :key="audited_change.field" v-for="audited_change in history.audited_changes">
                <p class="mb-1">
                  <strong>{{audited_change.field}}</strong> was changed from
                  <br/>
                  <span class="historyChangeText">{{audited_change.prev_value ? audited_change.prev_value : '*no value*'}}</span>
                  <br/>to<br/>
                  <span class="historyChangeText">{{audited_change.new_value ? audited_change.new_value : '*no value*'}}</span>
                </p>
                <RuleRevertModal 
                  @ruleUpdated="(id) => $emit('ruleUpdated', id)" 
                  :rule="rule" :history="history" 
                  :audited_change="audited_change"
                  :statuses="statuses"
                  :severities="severities"
                />
              </div>
            </b-collapse>
          </template>

          <!-- Create on the rule itself -->
          <template v-if="history.action == 'create'">
            <p class="ml-3 mb-0 text-success">{{friendlyAuditableType(history.auditable_type)}} was created</p>
          </template>
        </template>

        <!-- Edit or Deletion on one of the Rule's associated records-->
        <template v-else>
           <!-- Create on the rule associated record -->
          <template v-if="history.action == 'create'">
            <p class="ml-3 mb-0 text-success">{{friendlyAuditableType(history.auditable_type)}} was created</p>
          </template>

          <!-- Edit on the associated record -->
          <template v-if="history.action == 'update'">
            <a class="ml-3 text-info clickable" v-b-toggle="`history-collapse-${history.id}`">{{friendlyAuditableType(history.auditable_type)}} Updated...</a>
            <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
              <div class="ml-3 mb-3" :key="audited_change.field" v-for="audited_change in history.audited_changes">
                <p class="mb-1">
                  <strong>{{audited_change.field}}</strong> was changed from
                  <br/>
                  <span class="historyChangeText">{{audited_change.prev_value ? audited_change.prev_value : '*no value*'}}</span>
                  <br/>to<br/>
                  <span class="historyChangeText">{{audited_change.new_value ? audited_change.new_value : '*no value*'}}</span>
                </p>
                <RuleRevertModal
                  @ruleUpdated="(id) => $emit('ruleUpdated', id)"
                  :rule="rule" :history="history"
                  :audited_change="audited_change"
                  :statuses="statuses"
                  :severities="severities"
                />
              </div>
            </b-collapse>
          </template>

          <!-- Deletion on the associated record -->
          <template v-if="history.action == 'destroy'">
            <a class="ml-3 text-danger clickable" v-b-toggle="`history-collapse-${history.id}`">{{friendlyAuditableType(history.auditable_type)}} Deleted...</a>
            <b-collapse :id="`history-collapse-${history.id}`" class="mt-2">
              <div class="ml-3 mb-1" :key="audited_change.field" v-for="audited_change in history.audited_changes">
                <p class="mb-1">
                  <strong>{{audited_change.field}}</strong>:
                  <span class="historyChangeText">{{audited_change.new_value ? audited_change.new_value : '*no value*'}}</span>
                </p>
              </div>
              <div class="ml-3 mb-1">
                <RuleRevertModal 
                  @ruleUpdated="(id) => $emit('ruleUpdated', id)" 
                  :rule="rule" :history="history" 
                  :audited_change="null"
                  :statuses="statuses"
                  :severities="severities"
                />
              </div>
            </b-collapse>
          </template>
        </template>
      </div>
    </b-collapse>
  </div>
</template>

<script>
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
export default {
  name: 'RuleHistories',
  mixins: [DateFormatMixinVue, AlertMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
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
  data: function() {
    return {
      showHistories: false
    }
  },
  methods: {
    friendlyAuditableType: function(type) {
      if (type == 'RuleDescription') {
        return 'Rule Description';
      } else if (type == 'DisaRuleDescription') {
        return 'Rule Description';
      }

      return type;
    }
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
