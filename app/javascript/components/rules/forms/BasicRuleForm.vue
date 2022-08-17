<template>
  <div>
    <b-form>
      <RuleForm
        :rule="rule"
        :statuses="statuses"
        :severities="severities_map"
        :disabled="disabled"
        :fields="ruleFormFields"
        :disa_fields="disaDescriptionFormFields"
        :check_fields="checkFormFields"
        :force_enable_additional_questions="forceEnableAdditionalQuestions"
        :additional_questions="additional_questions"
      />
    </b-form>

    <RuleSecurityRequirementsGuideInformation
      :nist_control_family="rule.nist_control_family"
      :srg_rule="rule.srg_rule_attributes"
      :cci="rule.ident"
    />

    <!-- Some fields are only applicable if status is 'Applicable - Configurable' -->
    <div v-if="rule.status != 'Applicable - Configurable'">
      <hr />
      <p>
        <small>Some fields are hidden due to the control's status.</small>
      </p>
    </div>
  </div>
</template>

<script>
import RuleForm from "./RuleForm.vue";
import RuleSecurityRequirementsGuideInformation from "../RuleSecurityRequirementsGuideInformation.vue";

export default {
  name: "BasicRuleForm",
  components: {
    RuleForm,
    RuleSecurityRequirementsGuideInformation,
  },
  props: {
    rule: {
      type: Object,
      required: true,
    },
    statuses: {
      type: Array,
      required: true,
    },
    severities_map: {
      type: Object,
      required: true,
    },
    readOnly: {
      type: Boolean,
      default: false,
    },
    additional_questions: {
      type: Array,
      default: () => [],
    },
  },
  computed: {
    disabled: function () {
      return this.readOnly ||
        this.rule.locked ||
        this.rule.satisfied_by.length > 0 ||
        this.rule.review_requestor_id
        ? true
        : false;
    },
    // Still allow additional questions to be edited except when the control is actually
    // locked, or if a review is requested or this is a read only view.
    forceEnableAdditionalQuestions: function () {
      return !this.readOnly && !this.rule.locked && !this.rule.review_requestor_id;
    },
    // The fields to show need to be dynamic based on the rule status
    ruleFormFields: function () {
      if (this.rule.satisfied_by.length > 0 || this.rule.status == "Applicable - Configurable") {
        return {
          displayed: [
            "status",
            "title",
            "rule_severity",
            "fixtext",
            "vendor_comments",
            "nist_control",
          ],
          disabled: this.rule.satisfied_by.length > 0 ? ["title", "fixtext"] : [],
        };
      } else if (this.rule.status == "Not Yet Determined") {
        return {
          displayed: ["status", "title"],
          disabled: ["title"],
        };
      } else if (this.rule.status == "Applicable - Inherently Meets") {
        return {
          displayed: ["status", "status_justification", "artifact_description", "vendor_comments"],
          disabled: [],
        };
      } else if (this.rule.status == "Applicable - Does Not Meet") {
        return {
          displayed: ["status", "status_justification", "vendor_comments"],
          disabled: [],
        };
      } else if (this.rule.status == "Not Applicable") {
        return {
          displayed: ["status", "status_justification", "artifact_description", "vendor_comments"],
          disabled: [],
        };
      }
      return { displayed: [], disabled: [] };
    },
    disaDescriptionFormFields: function () {
      if (this.rule.status == "Applicable - Configurable") {
        return { displayed: ["vuln_discussion"], disabled: [] };
      } else if (this.rule.status == "Applicable - Does Not Meet") {
        return {
          displayed: ["mitigations_available", "mitigations", "poam_available", "poam"],
          disabled: [],
        };
      } else if (this.rule.status == "Not Yet Determined") {
        return { displayed: ["vuln_discussion"], disabled: ["vuln_discussion"] };
      } else {
        return { displayed: [], disabled: [] };
      }
    },
    checkFormFields: function () {
      return {
        displayed: [
          // "system",
          // "content_ref_name",
          // "content_ref_href",
          "content",
        ],
        disabled: [],
      };
    },
  },
};
</script>

<style scoped></style>
