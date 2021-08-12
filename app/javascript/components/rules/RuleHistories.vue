<template>
  <div>

    <div @click="showHistories = !showHistories">
      <h2 class="historiesHeading">Histories</h2>
      <b-badge pill class="superVerticalAlign">{{rule.histories.length}}</b-badge>

      <i class="mdi mdi-menu-down superVerticalAlign collapsableArrow" v-if="showHistories"></i>
      <i class="mdi mdi-menu-up superVerticalAlign collapsableArrow" v-if="!showHistories"></i>
    </div>

    <!-- All histories -->
    <b-collapse id="collapse-histories" v-model="showHistories">
      <div :key="history.id" v-for="history in rule.histories">
        <p class="historyHeader"><strong>{{history.name}}</strong></p>
        <p class="historyTimestamp"><small>{{friendlyDateTime(history.created_at)}}</small></p>
        <div class="historyBody" :key="audited_change.field" v-for="audited_change in history.audited_changes">
          <p class="historyDescription">{{formattedHistoryBody(audited_change)}}</p>
          <b-button v-if="rule.locked == false" class="revertButton" variant="warning" @click="revertHistory(history)">Revert</b-button>
        </div>
      </div>
    </b-collapse>
  </div>
</template>

<script>
export default {
  name: 'RuleHistories',
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
    revertHistory: function(history) {
      alert("Would have tried to revert history: " + history);
    },
    formattedHistoryBody: function(audited_change) {
      if (audited_change.prev_value == null) {
        return audited_change.field + " was changed to '" + audited_change.new_value + "'"
      } else { // Assume type is String
        return audited_change.field + " was changed from '" + audited_change.old_value + "' to '" + audited_change.new_value + "'"
      }
    },
    friendlyDateTime(dateTimeString) {
      const date = new Date(dateTimeString);
      const hours = date.getHours();
      const amOrPm = hours < 12 ? ' AM' : ' PM';
      const minutes = date.getMinutes() < 10 ? "0" + date.getMinutes() : date.getMinutes()
      const timeString = (hours > 12 ? hours - 12 : hours) + ":" + minutes + amOrPm;
      return date.toDateString() + " @ " + timeString;
    }
  }
}
</script>

<style scoped>
.historyHeader {
  margin: 1em 0em 0em 1em;
}

.historyTimestamp {
    margin: 0em 0em 0em 1em;
}

.historyBody {
  margin: 0em 0em 1em 2em;
}

.revertButton {
  padding: 0em 0.5em 0em 0.5em;
}

.historyDescription {
 margin: 0;
}

.superVerticalAlign {
  vertical-align: super;
}

.historiesHeading {
  display: inline-block;
  margin: 0;
}

.collapsableArrow {
  font-size: 1.5em;
}
</style>
