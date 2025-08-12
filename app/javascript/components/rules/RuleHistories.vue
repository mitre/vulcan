<template>
  <div>
    <!-- Collapsable header -->
    <div class="clickable" @click="showHistories = !showHistories">
      <h2 class="m-0 d-inline-block">Revision History</h2>
      <b-badge v-if="rule.histories" pill class="ml-1 superVerticalAlign">{{
        groupedRuleHistories.length
      }}</b-badge>

      <b-icon v-if="showHistories" icon="chevron-down" />
      <b-icon v-if="!showHistories" icon="chevron-up" />
    </div>

    <!-- All histories -->
    <b-collapse id="collapse-histories" v-model="showHistories">
      <History
        :histories="rule.histories"
        :component="component"
        :rule="rule"
        :statuses="statuses"
        :severities="severities"
      />
    </b-collapse>
  </div>
</template>

<script>
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import History from "../shared/History.vue";
import HistoryGroupingMixinVue from "../../mixins/HistoryGroupingMixin.vue";

export default {
  name: "RuleHistories",
  components: { History },
  mixins: [DateFormatMixinVue, AlertMixinVue, HistoryGroupingMixinVue],
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
    component: {
      type: Object,
      required: true,
    },
  },
  data: function () {
    return {
      showHistories: true,
    };
  },
  computed: {
    groupedRuleHistories() {
      return this.groupHistories(this.rule.histories);
    },
  },
};
</script>

<style scoped>
.historyChangeText {
  background: rgb(0, 0, 0, 0.1);
  border: 1px solid rgb(0, 0, 0, 0);
  border-radius: 0.25em;
}
</style>
