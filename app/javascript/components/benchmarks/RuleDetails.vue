<!-- RuleDetails.vue - Generic rule details for benchmarks -->
<template>
  <div class="card h-100">
    <div v-if="!selectedRule" class="card-body text-center text-muted py-5">
      <p>Select a rule from the list to view details.</p>
    </div>
    <template v-else>
      <div class="card-header">
        <h5 class="card-title">{{ selectedRule.title }}</h5>
      </div>
      <div class="card-body">
        <b-form>
          <!-- Vulnerability Discussion -->
          <DisaRuleDescriptionForm
            v-if="hasDisaDescription"
            :rule="selectedRule"
            :index="0"
            :description="selectedRule.disa_rule_descriptions_attributes[0]"
            :disabled="true"
            :fields="disaDescriptionFormFields"
          />

          <!-- Check Content -->
          <CheckForm
            v-if="hasCheck"
            :rule="selectedRule"
            :index="0"
            :disabled="true"
            :fields="checkFormFields"
          />

          <!-- Fix Text -->
          <RuleFormGroup
            v-if="selectedRule.fixtext"
            field-name="fixtext"
            label="Fix"
            tooltip="Describe how to correctly configure the requirement to remediate the system vulnerability"
            :fields="fixtextFields"
            :disabled="true"
            read-only
            id-prefix="rule"
          >
            <template #default="{ inputId, isDisabled }">
              <b-form-textarea
                :id="inputId"
                :value="selectedRule.fixtext"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
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
              <b-form-textarea
                :id="inputId"
                :value="selectedRule.vendor_comments"
                placeholder=""
                :disabled="isDisabled"
                rows="1"
                max-rows="99"
              />
            </template>
          </RuleFormGroup>
        </b-form>
      </div>
    </template>
  </div>
</template>

<script>
import DisaRuleDescriptionForm from "../rules/forms/DisaRuleDescriptionForm";
import CheckForm from "../rules/forms/CheckForm";
import RuleFormGroup from "../shared/RuleFormGroup.vue";

export default {
  name: "RuleDetails",
  components: { DisaRuleDescriptionForm, CheckForm, RuleFormGroup },
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg", "component"].includes(value),
    },
    selectedRule: {
      type: Object,
      required: false,
      default: () => null,
    },
  },
  computed: {
    hasDisaDescription() {
      return (
        this.selectedRule &&
        this.selectedRule.disa_rule_descriptions_attributes &&
        this.selectedRule.disa_rule_descriptions_attributes.length > 0
      );
    },
    hasCheck() {
      return (
        this.selectedRule &&
        this.selectedRule.checks_attributes &&
        this.selectedRule.checks_attributes.length > 0
      );
    },
    disaDescriptionFormFields() {
      return { displayed: ["vuln_discussion"], disabled: [] };
    },
    checkFormFields() {
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
