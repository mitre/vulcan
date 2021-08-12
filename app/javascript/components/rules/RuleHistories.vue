<template>
  <div>
    <!-- Collapsable header -->
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
          <p class="historyDescription">
            {{audited_change.field}}
            was changed from
            <span class="historyChangeText">{{audited_change.prev_value == null ? 'no value' : audited_change.prev_value}}</span>
            to
            <span class="historyChangeText">{{audited_change.new_value}}</span>
          </p>
          <b-button v-if="rule.locked == false" class="revertButton" variant="warning" @click="revertHistory(audited_change)">Revert</b-button>
        </div>
      </div>
    </b-collapse>
  </div>
</template>

<script>
import axios from 'axios';
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
    revertHistory: function(audited_change) {
      console.log("revert history: " + JSON.stringify(audited_change));

      let payload = {};
      payload[audited_change.field] = audited_change.prev_value
      axios.defaults.headers.common['X-CSRF-Token'] = this.authenticityToken;
      axios.put(`/rules/${this.rule.id}`, payload)
      .then(this.revertSuccess)
      .catch(this.revertFailure);
    },
    revertSuccess: function(response) {
      this.$emit('ruleUpdated', this.rule.id);
    },
    revertFailure: function(response) {
      alert('failed to revert!')
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
 margin: 0 0 0.5em 0;
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

.historyChangeText {
  background: rgb(0, 0, 0, 0.1);
  border: 1px solid rgb(0, 0, 0, 0);
  border-radius: 0.25em;
  padding: 0.1em 0.25em 0.1em 0.25em;
}
</style>
