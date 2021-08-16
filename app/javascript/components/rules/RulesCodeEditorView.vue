<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <RuleNavigator @ruleSelected="handleRuleSelected($event)" :rules="rules" :selectedRuleId="selectedRuleId" />
    </div>

    <template v-if="selectedRuleId != null">
      <div class="col-10">
        <RuleEditorHeader @ruleUpdated="(id) => $emit('ruleUpdated', id)" :rule="selectedRule" />
        
        <hr/>

        <div class="row">
          <!-- Main editor column -->
          <div class="col-7">
            <RuleViewer v-if="selectedRule.locked" :rule="selectedRule" />
            <RuleEditor v-else :rule="selectedRule" :statuses="statuses" :severities="severities" />
          </div>

          <!-- Additional info column -->
          <div class="col-5">
            <RuleComments @ruleUpdated="(id, updated) => $emit('ruleUpdated', id, updated)" :rule="selectedRule"/>
            <br/>
            <RuleHistories @ruleUpdated="(id) => $emit('ruleUpdated', id)" :rule="selectedRule"/>
          </div>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="col-10">
        <p class="text-center">No control currently selected. Select a control on the left to view or edit.</p>
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
  data: function () {
    return {
      selectedRuleId: null, // Integer for rule id
    }
  },
  computed: {
    selectedRule: function() {
      return this.rules.find(rule => rule.id == this.selectedRuleId);
    },
    lastEditor: function() {
      const histories = this.selectedRule.histories;
      if (histories.length > 0) {
        return histories[histories.length - 1].name
      }
      return 'Unknown User'
    }
  },
  methods: {
    handleRuleSelected: function(event) {
      this.selectedRuleId = event;
    },
  },
}
</script>

<style scoped>
</style>
