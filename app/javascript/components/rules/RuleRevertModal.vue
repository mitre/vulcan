<template>
  <div>
    <b-button
      v-if="rule.locked == false && afterState && !isEmpty(afterState)"
      class="px-2 py-0"
      variant="warning"
      @click="showModal()"
    >
      Revert
    </b-button>

    <b-modal
      ref="revertModal"
      title="Revert Rule History"
      size="xl"
      ok-title="Revert"
      @ok="revertHistory()"
    >
      <div class="row">
        <!-- CURRENT STATE -->
        <div class="col-6">
          <p class="h3">State Before Revert</p>

          <template v-if="history.action == 'destroy'">
            <p>No Current State - Deleted</p>
          </template>

          <template v-else-if="history.auditable_type == 'Rule'">
            <RuleForm
              :rule="rule"
              :statuses="statuses"
              :severities="severities"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
          </template>

          <template v-else-if="history.auditable_type == 'RuleDescription'">
            <RuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>Description does not exist.</p>
          </template>

          <template v-else-if="history.auditable_type == 'DisaRuleDescription'">
            <DisaRuleDescriptionForm
              v-if="!isEmpty(currentState)"
              :description="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>Description does not exist.</p>
          </template>

          <template v-else-if="history.auditable_type == 'Check'">
            <CheckForm
              v-if="!isEmpty(currentState)"
              :check="currentState"
              :disabled="true"
              :invalid-feedback="formFeedback"
            />
            <p v-else>Check does not exist.</p>
          </template>
        </div>

        <!-- STATE AFTER REVERT -->
        <div class="col-6">
          <p class="h3">State After Revert</p>

          <p v-if="!afterState || isEmpty(afterState)">Could not determine resulting state.</p>

          <RuleForm
            v-else-if="history.auditable_type == 'Rule'"
            :rule="afterState"
            :statuses="statuses"
            :severities="severities"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <RuleDescriptionForm
            v-else-if="history.auditable_type == 'RuleDescription'"
            :description="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <DisaRuleDescriptionForm
            v-else-if="history.auditable_type == 'DisaRuleDescription'"
            :description="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <CheckForm
            v-else-if="history.auditable_type == 'Check'"
            :check="afterState"
            :disabled="true"
            :valid-feedback="formFeedback"
          />

          <p v-else>Could not determine resulting state.</p>
        </div>
      </div>
    </b-modal>
  </div>
</template>

<script>
import axios from "axios";
import AlertMixinVue from "../../mixins/AlertMixin.vue";
import EmptyObjectMixinVue from "../../mixins/EmptyObjectMixin.vue";
import FormMixinVue from "../../mixins/FormMixin.vue";
import RuleForm from "./forms/RuleForm";
import RuleDescriptionForm from "./forms/RuleDescriptionForm";
import DisaRuleDescriptionForm from "./forms/DisaRuleDescriptionForm";
import CheckForm from "./forms/CheckForm";

export default {
  name: "RuleRevertModal",
  components: {
    RuleForm,
    RuleDescriptionForm,
    DisaRuleDescriptionForm,
    CheckForm,
  },
  mixins: [AlertMixinVue, EmptyObjectMixinVue, FormMixinVue],
  props: {
    rule: {
      type: Object,
      required: true,
    },
    history: {
      type: Object,
      required: true,
    },
    audited_change: {
      type: Object,
      required: false,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities: {
      type: Array,
      required: true,
    },
  },
  computed: {
    modalId: function () {
      return `revert-modal-${this.history.id}-${this.audited_change["field"] || "unknown"}`;
    },
    currentState: function () {
      let dependentRecord = {};
      if (this.history.auditable_type == "Rule") {
        dependentRecord = this.rule;
      } else if (this.history.auditable_type == "RuleDescription") {
        dependentRecord = this.rule.rule_descriptions_attributes.find(
          (e) => e.id == this.history.auditable_id
        );
      } else if (this.history.auditable_type == "DisaRuleDescription") {
        dependentRecord = this.rule.disa_rule_descriptions_attributes.find(
          (e) => e.id == this.history.auditable_id
        );
      } else if (this.history.auditable_type == "Check") {
        dependentRecord = this.rule.checks_attributes.find(
          (e) => e.id == this.history.auditable_id
        );
      }

      let curState = Object.assign({}, dependentRecord);
      if (this.isEmpty(curState)) {
        return {};
      }

      delete curState._destroy;
      return curState;
    },
    afterState: function () {
      // Get `currentState` and duplicate for modification
      let afterState = Object.assign({}, this.currentState);

      // Could not find the before state because the record was either
      // deleted or something went wrong and `{}` was returned by `currentState`
      if (this.isEmpty(afterState)) {
        // `this.audited_change == null` implies that action was a deletion
        // This means that `afterState` needs to be populated with the entirety of `history.audited_changes`
        if (this.audited_change == null) {
          for (let i = 0; i < this.history.audited_changes.length; i++) {
            afterState[this.history.audited_changes[i].field] =
              this.history.audited_changes[i].new_value;
          }
          return afterState;
        }
        return {};
      }

      // For and edit, just update the single `audited_change` from `currentState`
      afterState[this.audited_change.field] = this.audited_change.prev_value;
      return afterState;
    },
    // Generate `formFeedback` to be fed to resulting forms to
    // visually display which fields will be changed by a revert.
    formFeedback: function () {
      let formFeedback = {};
      if (this.audited_change == null) {
        for (let i = 0; i < this.history.audited_changes.length; i++) {
          formFeedback[this.history.audited_changes[i].field] = "";
        }
        return formFeedback;
      }

      formFeedback[this.audited_change.field] = "";
      return formFeedback;
    },
  },
  methods: {
    showModal: function () {
      this.$refs["revertModal"].show();
    },
    revertHistory: function () {
      let payload = {
        audit_id: this.history.id,
        field: this.audited_change ? this.audited_change.field : null,
      };
      axios
        .post(`/rules/${this.rule.id}/revert`, payload)
        .then(this.revertSuccess)
        .catch(this.alertOrNotifyResponse);
    },
    revertSuccess: function (response) {
      this.alertOrNotifyResponse(response);
      this.$emit("ruleUpdated", this.rule.id, "all");
    },
  },
};
</script>

<style scoped></style>
