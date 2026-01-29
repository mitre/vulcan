<template>
  <div>
    <div class="mb-2">
      <strong>Revision History</strong>
      <b-badge v-if="rule.histories" pill variant="info" class="ml-1">{{
        groupedRuleHistories.length
      }}</b-badge>
    </div>

    <History
      :histories="rule.histories"
      :component="component"
      :rule="rule"
      :statuses="statuses"
      :severities="severities"
    />

    <p v-if="!rule.histories || rule.histories.length === 0" class="text-muted small">
      No revision history yet.
    </p>
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
    return {};
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
