<template>
  <div>
    <b-tabs>
      <b-tab title="Documentation" class="pt-3" active>
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
          :statuses="statuses"
          :severities="severities"
          :read-only="readOnly"
          :additional_questions="additional_questions"
        />

        <BasicRuleForm
          v-else
          :rule="rule"
          :statuses="statuses"
          :severities_map="severities_map"
          :read-only="readOnly"
          :additional_questions="additional_questions"
        />
      </b-tab>
      <b-tab title="Inspec Control Body" class="pt-3">
        <MonacoEditor
          :value="rule.inspec_control_body"
          :options="monacoEditorOptions"
          @input="$root.$emit('update:rule', { ...rule, inspec_control_body: $event })"
        />
      </b-tab>
      <b-tab title="Inspec Control (Read-Only)" class="pt-3">
        <MonacoEditor
          :value="rule.inspec_control_file"
          :options="{ ...monacoEditorOptions, readOnly: true }"
        />
      </b-tab>
    </b-tabs>
  </div>
</template>

<script>
import MonacoEditor from "monaco-editor-vue";
import BasicRuleForm from "./forms/BasicRuleForm.vue";
import AdvancedRuleForm from "./forms/AdvancedRuleForm.vue";

export default {
  name: "RuleEditor",
  components: { MonacoEditor, BasicRuleForm, AdvancedRuleForm },
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
    additional_questions: {
      type: Array,
      default: () => [],
    },
  },
  data: function () {
    return {
      advancedEditor: false,
      monacoEditorOptions: {
        automaticLayout: true,
        heigh: "800",
        language: "ruby",
        minimap: {
          enabled: false,
        },
        readOnly: this.readOnly,
        "semanticHighlighting.enabled": true,
        tabSize: 2,
        theme: "vs-dark",
        width: "auto",
      },
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
