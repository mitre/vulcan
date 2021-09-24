<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <h2>{{ `${this.projectPrefix}-${rule.id}` }}</h2>

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
        <!-- Save rule -->
        <CommentModal
          title="Save Control"
          message="Provide a comment that summarizes your changes to this control."
          :require-non-empty="true"
          button-text="Save Control"
          button-variant="success"
          :button-disabled="false"
          wrapper-class="d-inline-block"
          @comment="saveRule($event)"
        />

        <!-- Delete rule -->
        <b-button v-b-modal.delete-rule-modal variant="danger">Delete Control</b-button>
        <b-modal
          id="delete-rule-modal"
          title="Delete Control"
          centered
          @ok="$root.$emit('delete:rule', rule.id)"
        >
          <p class="my-4">
            Are you sure you want to delete this control?<br />This cannot be undone.
          </p>

          <template #modal-footer="{ cancel, ok }">
            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button @click="cancel()"> Cancel </b-button>
            <b-button variant="danger" @click="ok()"> Permanently Delete Control </b-button>
          </template>
        </b-modal>

        <!-- Duplicate rule -->
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
import CommentModal from "../shared/CommentModal.vue";

export default {
  name: "RuleEditorHeader",
  components: { CommentModal },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    projectPrefix: {
      type: String,
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
      this.$root.$emit("refresh:rule", this.rule.id);
    },
    saveRule(comment) {
      const payload = {
        rule: {
          ...this.rule,
          audit_comment: comment,
        },
      };
      axios
        .put(`/rules/${this.rule.id}`, payload)
        .then(this.saveRuleSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    saveRuleSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$root.$emit("refresh:rule", this.rule.id);
    },
  },
};
</script>

<style scoped></style>
