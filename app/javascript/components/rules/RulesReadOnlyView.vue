<template>
  <div class="row">
    <div id="sidebar-wrapper" class="col-3 pr-0">
      <RuleNavigator
        :component-id="component.id"
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :effective-permissions="effectivePermissions"
        :project-prefix="component.prefix"
        :read-only="true"
        :open-rule-ids="openRuleIds"
        @ruleSelected="handleRuleSelected($event)"
        @ruleDeselected="handleRuleDeselected($event)"
      />
    </div>

    <template v-if="selectedRule()">
      <div class="col-9 mb-5">
        <RuleEditorHeader
          :rule="selectedRule()"
          :rules="rules"
          :effective-permissions="effectivePermissions"
          :current-user-id="currentUserId"
          :project-prefix="component.prefix"
          :read-only="true"
        />
        <hr />
        <RuleEditor
          :rule="selectedRule()"
          :statuses="statuses"
          :severities="severities"
          :severities_map="severities_map"
          :read-only="true"
          :advanced_fields="component.advanced_fields"
          :additional_questions="component.additional_questions"
        />
      </div>
    </template>

    <template v-else>
      <div class="col-9">
        <p class="text-center">
          No control currently selected. Select a control on the left to view.
        </p>
      </div>
    </template>
  </div>
</template>

<script>
import RuleEditorHeader from "./RuleEditorHeader.vue";
import RuleEditor from "./RuleEditor.vue";
import RuleNavigator from "./RuleNavigator.vue";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin.vue";

export default {
  name: "RulesReadOnlyView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleEditorHeader,
  },
  mixins: [SelectedRulesMixin],
  props: {
    effectivePermissions: {
      type: String,
      default: "",
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    component: {
      type: Object,
      required: true,
    },
    rules: {
      type: Array,
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
    componentSelectedRuleId: {
      type: Number,
      required: false,
    },
  },
  watch: {
    selectedRuleId: function () {
      this.$emit("ruleSelected", this.selectedRule());
    },
    componentSelectedRuleId: function (ruleId) {
      this.handleRuleSelected(ruleId);
    },
  },
};
</script>

<style scoped></style>
