<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <h2>{{ rule.rule_id }}</h2>

      <!-- Rule info -->
      <!-- <p>Based on ...</p> -->
      <p v-if="rule.histories.length > 0">
        Last updated on {{ friendlyDateTime(rule.updated_at) }} by
        {{ lastEditor }}
      </p>
      <p v-else>Created on {{ friendlyDateTime(rule.created_at) }}</p>

      <!-- Action Buttons -->
      <!-- Disable and enable save & delete buttons based on locked state of rule -->
      <template v-if="rule.locked">
        <span v-b-tooltip.hover class="d-inline-block" title="Control is locked.">
          <b-button variant="success" disabled>Save Control</b-button>
        </span>
        <span v-b-tooltip.hover class="d-inline-block" title="Control is locked.">
          <b-button variant="danger" disabled>Delete Control</b-button>
        </span>
      </template>
      <template v-else>
        <b-button variant="success" @click="saveRule()">Save Control</b-button>
        <b-button variant="danger">Delete Control</b-button>
        <!-- <b-button>Duplicate Control</b-button> -->
      </template>
      <b-button v-if="rule.locked" variant="warning" @click="manageLock(false)"
        >Unlock Control</b-button
      >
      <b-button v-else variant="warning" @click="manageLock(true)">Lock Control</b-button>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";

export default {
  name: "RuleEditorHeader",
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
  },
  computed: {
    lastEditor: function () {
      const histories = this.rule.histories;
      if (histories.length > 0) {
        return histories[histories.length - 1].name;
      }
      return "Unknown User";
    },
  },
  methods: {
    manageLock: function (desiredLockState) {
      axios
        .post(`/rules/${this.rule.id}/manage_lock`, {
          locked: desiredLockState,
        })
        .then(this.manageLockSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    manageLockSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("ruleUpdated", this.rule.id, "all");
    },
    saveRule() {
      axios
        .put(`/rules/${this.rule.id}`, this.rule)
        .then(this.saveRuleSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    saveRuleSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("ruleUpdated", this.rule.id, "all");
    },
  },
};
</script>

<style scoped></style>
