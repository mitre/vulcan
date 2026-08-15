<!-- RuleDetails.vue - Generic rule details for benchmarks -->
<template>
  <div class="card h-100">
    <div v-if="!selectedRule" class="card-body text-center text-muted py-5">
      <p>Select a {{ itemTerm.singular.toLowerCase() }} from the list to view details.</p>
    </div>
    <template v-else>
      <div class="card-header">
        <h5 class="card-title">{{ selectedRule.title }}</h5>
      </div>
      <div class="card-body">
        <SatisfiedByIndicator
          v-if="satisfiedByParents.length > 0"
          :parent-rules="satisfiedByParents"
        >
          Covered by its parent {{ itemTerm.singular.toLowerCase() }} in this release.
          <template #actions>
            <span />
          </template>
        </SatisfiedByIndicator>
        <b-form>
          <!-- Vulnerability Discussion -->
          <RuleFormGroup
            v-if="hasDisaDescription"
            field-name="vuln_discussion"
            label="Vulnerability Discussion"
            tooltip="Description of the vulnerability with details and context"
            :fields="vulnDiscussionFields"
            :disabled="true"
            read-only
            id-prefix="rule"
          >
            <template #default="{ inputId, isDisabled }">
              <MarkdownTextarea
                :id="inputId"
                :value="disaDescriptionValue"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
                plain-text
              />
            </template>
          </RuleFormGroup>

          <!-- Check Content -->
          <RuleFormGroup
            v-if="hasCheck"
            field-name="content"
            label="Check"
            tooltip="Procedure or script to verify system compliance"
            :fields="checkFields"
            :disabled="true"
            read-only
            id-prefix="rule"
          >
            <template #default="{ inputId, isDisabled }">
              <MarkdownTextarea
                :id="inputId"
                :value="checkContentValue"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
                plain-text
              />
            </template>
          </RuleFormGroup>

          <!-- Fix Text -->
          <RuleFormGroup
            v-if="selectedRule.fixtext"
            field-name="fixtext"
            label="Fix"
            :tooltip="`Describe how to correctly configure the ${itemTerm.singular.toLowerCase()} to remediate the system vulnerability`"
            :fields="fixtextFields"
            :disabled="true"
            read-only
            id-prefix="rule"
          >
            <template #default="{ inputId, isDisabled }">
              <MarkdownTextarea
                :id="inputId"
                :value="selectedRule.fixtext"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
                plain-text
              />
            </template>
          </RuleFormGroup>

          <!-- Vendor Comment (if present) -->
          <RuleFormGroup
            v-if="selectedRule.vendor_comments"
            field-name="vendor_comments"
            label="Vendor Comments"
            tooltip="Provide context to a reviewing authority; not a published field"
            :fields="vendorCommentsFields"
            :disabled="true"
            read-only
            id-prefix="rule"
          >
            <template #default="{ inputId, isDisabled }">
              <MarkdownTextarea
                :id="inputId"
                :value="selectedRule.vendor_comments"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
                plain-text
              />
            </template>
          </RuleFormGroup>
        </b-form>
      </div>
    </template>
  </div>
</template>

<script>
import { RULE_TERM } from "../../constants/terminology";
import RuleFormGroup from "../shared/RuleFormGroup.vue";
import MarkdownTextarea from "../shared/MarkdownTextarea.vue";
import SatisfiedByIndicator from "../shared/SatisfiedByIndicator.vue";
import { ruleArray } from "../../utils/ruleArray";

export default {
  name: "RuleDetails",
  components: { RuleFormGroup, MarkdownTextarea, SatisfiedByIndicator },
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg", "component"].includes(value),
    },
    // Resolved display noun from the parent viewer (kind-aware for
    // released components); defaults to the deployment term.
    itemTerm: {
      type: Object,
      default: () => RULE_TERM,
    },
    selectedRule: {
      type: Object,
      required: false,
      default: () => null,
    },
  },
  computed: {
    satisfiedByParents() {
      return ruleArray(this.selectedRule, "satisfied_by");
    },
    hasDisaDescription() {
      return ruleArray(this.selectedRule, "disa_rule_descriptions_attributes").length > 0;
    },
    hasCheck() {
      return ruleArray(this.selectedRule, "checks_attributes").length > 0;
    },
    disaDescriptionValue() {
      return (ruleArray(this.selectedRule, "disa_rule_descriptions_attributes")[0] || {})
        .vuln_discussion;
    },
    checkContentValue() {
      return (ruleArray(this.selectedRule, "checks_attributes")[0] || {}).content;
    },
    vulnDiscussionFields() {
      return { displayed: ["vuln_discussion"], disabled: [] };
    },
    checkFields() {
      return { displayed: ["content"], disabled: [] };
    },
    fixtextFields() {
      return { displayed: ["fixtext"], disabled: [] };
    },
    vendorCommentsFields() {
      return { displayed: ["vendor_comments"], disabled: [] };
    },
  },
};
</script>
