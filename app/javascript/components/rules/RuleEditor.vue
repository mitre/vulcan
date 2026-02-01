<template>
  <div>
    <b-tabs>
      <b-tab title="Documentation" class="pt-3" active>
        <!-- Actions Toolbar (always visible, buttons disabled when read-only) -->
        <RuleActionsToolbar
          :rule="rule"
          :effective-permissions="effectivePermissions"
          :read-only="readOnly"
          @clone="$emit('clone')"
          @delete="$emit('delete')"
          @save="$emit('save', $event)"
          @comment="$emit('comment', $event)"
          @open-review-modal="$emit('open-review-modal')"
          @lock="$emit('lock', $event)"
          @unlock="$emit('unlock', $event)"
        />

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
      <b-tab title="InSpec Control Body" lazy>
        <InspecControlEditor :rule="rule" field="inspec_control_body" :read-only="readOnly" />
      </b-tab>
      <b-tab title="InSpec Control (Read-Only)" lazy>
        <InspecControlEditor :rule="rule" field="inspec_control_file" :read-only="true" />
      </b-tab>
    </b-tabs>
  </div>
</template>

<script>
import BasicRuleForm from "./forms/BasicRuleForm.vue";
import AdvancedRuleForm from "./forms/AdvancedRuleForm.vue";
import InspecControlEditor from "./InspecControlEditor.vue";
import RuleActionsToolbar from "./RuleActionsToolbar.vue";

export default {
  name: "RuleEditor",
  components: { BasicRuleForm, AdvancedRuleForm, InspecControlEditor, RuleActionsToolbar },
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
    effectivePermissions: {
      type: String,
      default: "",
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
