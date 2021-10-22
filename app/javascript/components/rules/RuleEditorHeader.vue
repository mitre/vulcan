<template>
  <!-- Rule Details column -->
  <div class="row">
    <div class="col-12">
      <h2>
        <i v-if="rule.locked" class="mdi mdi-lock" aria-hidden="true" />
        <i v-if="rule.review_requestor_id" class="mdi mdi-file-find" aria-hidden="true" />
        <i v-if="rule.changes_requested" class="mdi mdi-delta" aria-hidden="true" />
        {{ `${projectPrefix}-${rule.id}` }} // {{ rule.version }}
      </h2>

      <p v-if="!readOnly && rule.locked" class="text-danger font-weight-bold">
        This control is locked and must first be unlocked if changes or deletion are required.
      </p>
      <p v-if="!readOnly && rule.review_requestor_id" class="text-danger font-weight-bold">
        This control is under review and cannot be edited at this time.
      </p>

      <div v-if="!readOnly">
        <!-- Rule info -->
        <!-- <p>Based on ...</p> -->
        <p v-if="rule.histories && rule.histories.length > 0">
          Last updated on {{ friendlyDateTime(rule.updated_at) }} by
          {{ lastEditor }}
        </p>
        <p v-else>Created on {{ friendlyDateTime(rule.created_at) }}</p>

        <!-- Action Buttons -->
        <!-- Duplicate rule modal -->
        <NewRuleModalForm
          :title="'Duplicate Control'"
          :id-prefix="'duplicate'"
          :for-duplicate="true"
          :selected-rule-id="rule.id"
          @ruleSelected="$emit('ruleSelected', $event.id)"
        />
        <b-button v-b-modal.duplicate-rule-modal variant="primary">Duplicate Control</b-button>
        <!-- Disable and enable save & delete buttons based on locked state of rule -->
        <template v-if="rule.locked || rule.review_requestor_id ? true : false">
          <span
            v-b-tooltip.hover
            class="d-inline-block"
            title="Cannot save a control that is locked or under review."
          >
            <b-button variant="success" disabled>Save Control</b-button>
          </span>
          <span
            v-if="effectivePermissions == 'admin'"
            v-b-tooltip.hover
            class="d-inline-block"
            title="Cannot delete a control that is locked or under review"
          >
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
          <b-button
            v-if="effectivePermissions == 'admin'"
            v-b-modal.delete-rule-modal
            variant="danger"
          >
            Delete Control
          </b-button>
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
        </template>
      </div>
    </div>
  </div>
</template>

<script>
import axios from "axios";
import DateFormatMixinVue from "../../mixins/DateFormatMixin.vue";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import CommentModal from "../shared/CommentModal.vue";
import NewRuleModalForm from "./forms/NewRuleModalForm.vue";

export default {
  name: "RuleEditorHeader",
  components: { CommentModal, NewRuleModalForm },
  mixins: [DateFormatMixinVue, AlertMixinVue, FormMixinVue],
  props: {
    effectivePermissions: {
      type: String,
      default: "",
    },
    rule: {
      type: Object,
      required: true,
    },
    projectPrefix: {
      type: String,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
  },
  computed: {
    lastEditor: function () {
      const histories = this.rule.histories;
      if (histories?.length > 0) {
        return histories[0].name || "Unknown User";
      }
      return "Unknown User";
    },
  },
  methods: {
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
