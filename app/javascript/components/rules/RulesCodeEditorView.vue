<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <RuleNavigator @ruleSelected="handleRuleSelected($event)" :rules="rules" :selectedRuleId="selectedRuleId" />
    </div>

    <template v-if="selectedRuleId != null">
      <div class="col-10">
        <!-- Rule Details column -->
        <div class="row">
          <div class="col-12">
            <h2>{{selectedRule.id}}</h2>

            <!-- Rule info -->
            <!-- <p>Based on ...</p> -->
            <p v-if="selectedRule.histories.length> 0">Last updated on {{friendlyDateTime(selectedRule.updated_at)}} by {{lastEditor}}</p>
            <p v-else>Created on {{friendlyDateTime(selectedRule.created_at)}}</p>

            <!-- Action Buttons -->
            <b-button variant="success">Save Control</b-button>
            <b-button variant="danger">Delete Control</b-button>
            <b-button variant="warning">Lock Control</b-button>
            <!-- <b-button>Duplicate Control</b-button> -->
          </div>
        </div>
        <hr/>

        <div class="row">
          <!-- Main editor column -->
          <div class="col-7">
            <p>description: {{selectedRule.description}}</p>
          </div>

          <!-- Additional info column -->
          <div class="col-5">
            <RuleComments @ruleUpdated="(id) => $emit('ruleUpdated', id)" :rule="selectedRule"/>
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
    // This needs to be an external helper
    friendlyDateTime: function(dateTimeString) {
      const date = new Date(dateTimeString);
      const hours = date.getHours();
      const amOrPm = hours < 12 ? ' AM' : ' PM';
      const minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
      const timeString = (hours > 12 ? hours - 12 : hours) + ":" + minutes + amOrPm;
      return `${date.toDateString()} @ ${timeString}`;
    }
  },
}
</script>

<style scoped>
</style>
