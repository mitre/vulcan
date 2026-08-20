<template>
  <div>
    <div class="mb-2">
      <strong>Changelog</strong>
      <b-badge v-if="rule.histories" pill variant="info" class="ml-1">{{
        groupedRuleHistories.length
      }}</b-badge>
    </div>

    <History :histories="rule.histories" :component="component" :rule="rule" :statuses="statuses" />

    <p v-if="!rule.histories || rule.histories.length === 0" class="text-muted small">
      No revision history yet.
    </p>
  </div>
</template>

<script>
import History from "../shared/History.vue";
import { useHistoryGrouping } from "../../composables/useHistoryGrouping";

export default {
  name: "RuleHistories",
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
    component: {
      type: Object,
      required: true,
    },
  },
  setup() {
    const { groupHistories } = useHistoryGrouping();
    return { groupHistories };
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
  background: var(--vulcan-overlay-medium);
  border: 1px solid var(--vulcan-border-transparent);
  border-radius: 0.25em;
}
</style>
