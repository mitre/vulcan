<template>
  <div>
    <AdvancedRuleForm
      v-if="advanced_fields"
      :rule="rule"
      :statuses="statuses"
      :severities="severities"
      :read-only="readOnly"
    />

    <BasicRuleForm
      v-else
      :rule="rule"
      :statuses="statuses"
      :severities="severities"
      :read-only="readOnly"
    />
  </div>
</template>

<script>
import BasicRuleForm from "./forms/BasicRuleForm.vue";
import AdvancedRuleForm from "./forms/AdvancedRuleForm.vue";

export default {
  name: "RuleEditor",
  components: { BasicRuleForm, AdvancedRuleForm },
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
    readOnly: {
      type: Boolean,
      default: false,
    },
    advanced_fields: {
      type: Boolean,
      default: false,
    },
  },
};
</script>

<style scoped></style>
