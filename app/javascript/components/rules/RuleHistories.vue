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
      <History
        :histories="rule.histories"
        :rule="rule"
        :statuses="statuses"
        :severities="severities"
        @ruleUpdated="(id) => $emit('ruleUpdated', id)"
      />
    </b-collapse>
  </div>
</template>

<script>
import DateFormatMixinVue from '../../mixins/DateFormatMixin.vue';
import AlertMixinVue from '../../mixins/AlertMixin.vue';
import History from '../shared/History.vue'

export default {
  name: 'RuleHistories',
  mixins: [DateFormatMixinVue, AlertMixinVue],
  components: { History },
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
    }
  },
  data: function() {
    return {
      showHistories: false
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
