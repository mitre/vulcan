<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <RuleNavigator @ruleSelected="handleRuleSelected($event)" :rules="rules" :selectedRule="selectedRule" />
    </div>

    <template v-if="selectedRule != null">
      <!-- Main editor column -->
      <div class="col-6">
        <p>selected control: {{selectedRule.id}}</p>
      </div>

      <!-- Additional info column -->
      <div class="col-4">
        <RuleComments :rule="selectedRule"/>
        <br/>
        <RuleHistories :rule="selectedRule"/>
      </div>
    </template>

    <template v-else>
      <div class="col-10">
        <p>Select a rule on the left to edit.</p>
      </div>
    </template>
    
  </div>
</template>

<script>
export default {
  name: 'RulesCodeEditorView',
  props: {
    project: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
      required: true,
    }
  },
  data: function () {
    return {
      selectedRule: null
    }
  },
  methods: {
    handleRuleSelected: function(event) {
      this.selectedRule = event;
    }
  }
}
</script>

<style scoped>
</style>
