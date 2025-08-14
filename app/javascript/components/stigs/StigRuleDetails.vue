<!-- StigRuleDetails.vue -->
<template>
  <div class="card h-100">
    <div class="card-header">
      <h5 class="card-title">{{ selectedRule.title }}</h5>
    </div>
    <div class="card-body">
      <b-form>
        <!-- Vulnerability Discussion -->
        <DisaRuleDescriptionForm
          :rule="selectedRule"
          :index="0"
          :description="selectedRule.disa_rule_descriptions_attributes[0]"
          :disabled="true"
          :fields="disaDescriptionFormFields"
        />
        <!-- checks -->
        <CheckForm :rule="selectedRule" :index="0" :disabled="true" :fields="checkFormFields" />

        <!-- fixtext -->
        <b-form-group>
          <label :for="`stig-rule-fixtext-${selectedRule.id}`">
            Fix
            <b-icon
              v-b-tooltip.hover.html
              icon="info-circle"
              aria-hidden="true"
              title="Describe how to correctly configure the requirement to remediate the system vulnerability"
            />
          </label>
          <b-form-textarea
            :id="`stig-rule-fixtext-${selectedRule.id}`"
            :value="selectedRule.fixtext"
            placeholder=""
            :disabled="true"
            rows="1"
            max-rows="99"
          />
        </b-form-group>

        <!-- Vendor Comment -->
        <b-form-group v-if="selectedRule.vendor_comments">
          <label :for="`stig-rule-vendor-comments-${selectedRule.id}`">
            Vendor Comments
            <b-icon
              v-b-tooltip.hover.html
              icon="info-circle"
              aria-hidden="true"
              title="Provide context to a reviewing authority; not a published field"
            />
          </label>
          <b-form-textarea
            :id="`stig-rule-vendor-comments-${selectedRule.id}`"
            :value="selectedRule.vendor_comments"
            placeholder=""
            :disabled="true"
            rows="1"
            max-rows="99"
          />
        </b-form-group>
      </b-form>
    </div>
  </div>
</template>

<script>
import DisaRuleDescriptionForm from "../rules/forms/DisaRuleDescriptionForm";
import CheckForm from "../rules/forms/CheckForm";
export default {
  name: "StigRuleDetails",
  components: { DisaRuleDescriptionForm, CheckForm },
  props: {
    selectedRule: {
      type: Object,
      required: true,
    },
  },
  computed: {
    disaDescriptionFormFields: function () {
      return { displayed: ["vuln_discussion"], disabled: [] };
    },
    checkFormFields: function () {
      return {
        displayed: ["content"],
        disabled: [],
      };
    },
  },
};
</script>

<style scoped></style>
