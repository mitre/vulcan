<template>
  <div>
    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :severities="severities"
        :disabled="disabledForm"
        :show-fields="ruleFormFields"
      />

      <!-- disa_rule_description -->
      <DisaRuleDescriptionForm
        v-if="
          rule.status == 'Applicable - Configurable' &&
          rule.disa_rule_descriptions_attributes.length >= 1
        "
        :rule="rule"
        :index="0"
        :description="rule.disa_rule_descriptions_attributes[0]"
        :disabled="disabledForm"
        :show-fields="disaDescriptionFormFields"
      />

      <!-- checks -->
      <CheckForm
        v-if="rule.status == 'Applicable - Configurable' && rule.checks_attributes.length >= 1"
        :rule="rule"
        :index="0"
        :check="rule.checks_attributes[0]"
        :disabled="disabledForm"
        :show-fields="checkFormFields"
      />
    </b-form>
  </div>
</template>

<script>
import RuleForm from "./RuleForm.vue";
import CheckForm from "./CheckForm.vue";
import DisaRuleDescriptionForm from "./DisaRuleDescriptionForm.vue";

export default {
  name: "BasicRuleForm",
  components: { RuleForm, CheckForm, DisaRuleDescriptionForm },
  props: {
    rule: {
      type: Object,
      required: true,
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
  data: function () {
    return {
      ruleFormFields: [
        "status",
        "status_justification",
        "title",
        // "version",
        "rule_severity",
        // "rule_weight",
        // "artifact_description",
        // "fix_id",
        // "fixtext_fixref",
        "fixtext",
        // "ident",
        // "ident_system",
        "vendor_comments",
      ],
      disaDescriptionFormFields: [
        // "documentable",
        "vuln_discussion",
        // "false_positives",
        // "false_negatives",
        // "mitigations",
        // "severity_override_guidance",
        // "potential_impacts",
        // "third_party_tools",
        "mitigation_control",
        // "responsibility",
        "ia_controls",
      ],
      checkFormFields: [
        // "system",
        // "content_ref_name",
        // "content_ref_href",
        "content",
      ],
    };
  },
  computed: {
    disabledForm: function () {
      return this.rule.locked || this.rule.review_requestor_id ? true : false;
    },
  },
};
</script>

<style scoped></style>
