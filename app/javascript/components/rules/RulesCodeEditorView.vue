<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <RuleNavigator @ruleSelected="handleRuleSelected($event)" :rules="rules" :selectedRuleId="selectedRuleId" />
    </div>

    <template v-if="selectedRuleId != null">
      <!-- Main editor column -->
      <div class="col-6">
        <p>selected control: {{selectedRuleId}}</p>
      </div>

      <!-- Additional info column -->
      <div class="col-4">
        <RuleComments @ruleUpdated="(id) => $emit('ruleUpdated', id)" :rule="selectedRule"/>
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
      selectedRuleId: null, // Integer for rule id
    }
  },
  computed: {
    selectedRule: function() {
      return this.rules.find(rule => rule.id == this.selectedRuleId);
    }
  },
  methods: {
    handleRuleSelected: function(event) {
      this.selectedRuleId = event;
    }
  },
}
</script>

<style scoped>
</style>
