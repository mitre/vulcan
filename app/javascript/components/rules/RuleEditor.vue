<template>
  <div>
    <p v-if="rule.locked" class="text-danger">
      This control is locked and must first be unlocked if changes or deletion are required.
    </p>

    <div class="mb-3 font-weight-bold">
      <span>Basic Editor&nbsp;</span>
      <b-form-checkbox
        v-model="advancedEditor"
        name="editor-selector-check-button"
        class="d-inline-block"
        switch
      >
        Advanced Editor
      </b-form-checkbox>
    </div>

    <AdvancedRuleForm
      v-if="advancedEditor"
      :rule="rule"
      :statuses="statuses"
      :severities="severities"
    />

    <BasicRuleForm v-else :rule="rule" :statuses="statuses" :severities="severities" />
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
  },
  data: function () {
    return {
      advancedEditor: false,
    };
  },
};
</script>

<style scoped></style>
