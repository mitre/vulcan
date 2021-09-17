<template>
  <div>
    <div class="mb-3 font-weight-bold">
      <b-form-checkbox
        v-model="advancedEditor"
        name="editor-selector-check-button"
        class="d-inline-block"
        switch
      >
        Advanced Fields
      </b-form-checkbox>
    </div>

    <AdvancedRuleForm
      v-if="advancedEditor"
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
  },
  data: function () {
    return {
      advancedEditor: false,
    };
  },
  watch: {
    advancedEditor: function (_) {
      localStorage.setItem("advancedEditor", JSON.stringify(this.advancedEditor));
    },
  },
  mounted: function () {
    // Persist `advancedEditor` across page loads
    if (localStorage.getItem("advancedEditor")) {
      try {
        this.advancedEditor = JSON.parse(localStorage.getItem("advancedEditor"));
      } catch (e) {
        localStorage.removeItem("advancedEditor");
      }
    }
  },
};
</script>

<style scoped></style>
