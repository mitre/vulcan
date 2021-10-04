<template>
  <div class="row">
    <div class="col-3">
      <RuleNavigator
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :project-permissions="projectPermissions"
        :project-prefix="project.prefix"
        :read-only="true"
        :open-rule-ids="openRuleIds"
        @ruleSelected="handleRuleSelected($event)"
        @ruleDeselected="handleRuleDeselected($event)"
      />
    </div>

    <template v-if="selectedRule()">
      <div class="col-9">
        <RuleEditorHeader
          :rule="selectedRule()"
          :project-permissions="projectPermissions"
          :project-prefix="project.prefix"
          :read-only="true"
        />
        <hr />
        <RuleEditor
          :rule="selectedRule()"
          :statuses="statuses"
          :severities="severities"
          :read-only="true"
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
    projectPermissions: {
      type: String,
      required: true,
    },
    currentUserId: {
      type: Number,
      required: true,
    },
    project: {
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
  },
};
</script>

<style scoped></style>
