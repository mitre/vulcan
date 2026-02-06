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
          <b-form-group v-if="selectedRule.fixtext">
            <label :for="`rule-fixtext-${selectedRule.id}`">
              Fix
              <b-icon
                v-b-tooltip.hover.html="
                  'Describe how to correctly configure the requirement to remediate the system vulnerability'
                "
                icon="info-circle"
                aria-hidden="true"
              />
            </label>
            <b-form-textarea
              :id="`rule-fixtext-${selectedRule.id}`"
              :value="selectedRule.fixtext"
              placeholder=""
              :disabled="true"
              rows="1"
              max-rows="99"
            />
          </b-form-group>

          <!-- Vendor Comment (if present) -->
          <b-form-group v-if="selectedRule.vendor_comments">
            <label :for="`rule-vendor-comments-${selectedRule.id}`">
              Vendor Comments
              <b-icon
                v-b-tooltip.hover.html="
                  'Provide context to a reviewing authority; not a published field'
                "
                icon="info-circle"
                aria-hidden="true"
              />
            </label>
            <b-form-textarea
              :id="`rule-vendor-comments-${selectedRule.id}`"
              :value="selectedRule.vendor_comments"
              placeholder=""
              :disabled="true"
              rows="1"
              max-rows="99"
            />
          </b-form-group>
        </b-form>
      </div>
    </template>
  </div>
</template>

<script>
import DisaRuleDescriptionForm from "../rules/forms/DisaRuleDescriptionForm";
import CheckForm from "../rules/forms/CheckForm";

export default {
  name: "RuleDetails",
  components: { DisaRuleDescriptionForm, CheckForm },
  props: {
    type: {
      type: String,
      required: true,
      validator: (value) => ["stig", "srg"].includes(value),
    },
    selectedRule: {
      type: Object,
      required: true,
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
      return {
        displayed: ["content"],
        disabled: [],
      };
    },
  },
};
</script>

<style scoped></style>
