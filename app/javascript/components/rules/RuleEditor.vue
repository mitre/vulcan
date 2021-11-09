<template>
  <div>
    <div v-if="advanced_fields" class="mb-3 font-weight-bold">
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
      :project-prefix="projectPrefix"
      :statuses="statuses"
      :severities="severities"
      :read-only="readOnly"
    />

    <BasicRuleForm
      v-else
      :rule="rule"
      :project-prefix="projectPrefix"
      :statuses="statuses"
      :severities_map="severities_map"
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
    projectPrefix: {
      type: String,
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
    severities_map: {
      type: Object,
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
