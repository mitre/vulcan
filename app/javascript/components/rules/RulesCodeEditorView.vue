<template>
  <div class="row">
    <div class="col-2">
      <RuleNavigator
        :component-id="component.id"
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :project-prefix="component.prefix"
        :effective-permissions="effectivePermissions"
        :open-rule-ids="openRuleIds"
        @ruleSelected="handleRuleSelected($event)"
        @ruleDeselected="handleRuleDeselected($event)"
      />
    </div>

    <template v-if="selectedRule()">
      <div class="col-10">
        <RuleEditorHeader
          :rule="selectedRule()"
          :project-prefix="component.prefix"
          :effective-permissions="effectivePermissions"
          @ruleSelected="handleRuleSelected($event)"
        />

        <hr />

        <div class="row">
          <!-- Main editor column -->
          <div class="col-7 border-right">
            <RuleEditor :rule="selectedRule()" :statuses="statuses" :severities="severities" />
          </div>

          <!-- Additional info column -->
          <div class="col-5">
            <RuleReviews
              :rule="selectedRule()"
              :effective-permissions="effectivePermissions"
              :current-user-id="currentUserId"
            />
            <br />
            <RuleHistories :rule="selectedRule()" :statuses="statuses" :severities="severities" />
          </div>
        </div>
      </div>
    </template>

    <template v-else>
      <div class="col-10">
        <p class="text-center">
          No control currently selected. Select a control on the left to view or edit.
        </p>
      </div>
    </template>
  </div>
</template>

<script>
import RuleEditorHeader from "./RuleEditorHeader.vue";
import RuleEditor from "./RuleEditor.vue";
import RuleNavigator from "./RuleNavigator.vue";
import RuleHistories from "./RuleHistories.vue";
import RuleReviews from "./RuleReviews.vue";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin.vue";

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleEditorHeader,
    RuleHistories,
    RuleReviews,
  },
  mixins: [SelectedRulesMixin],
  props: {
    effectivePermissions: {
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
  },
};
</script>

<style scoped></style>
