<template>
  <div class="row">
    <div id="sidebar-wrapper" class="col-2 pr-0">
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
      <div class="col-10 mb-5">
        <RuleEditorHeader
          :rule="selectedRule()"
          :rules="rules"
          :project-prefix="component.prefix"
          :effective-permissions="effectivePermissions"
          :current-user-id="currentUserId"
          @ruleSelected="handleRuleSelected($event)"
        />

        <hr />

        <div class="row">
          <!-- Main editor column -->
          <div class="col-8 border-right">
            <RuleEditor
              :rule="selectedRule()"
              :statuses="statuses"
              :severities="severities"
              :severities_map="severities_map"
              :advanced_fields="component.advanced_fields"
              :additional_questions="component.additional_questions"
            />
          </div>

          <!-- Additional info column -->
          <div class="col-4">
            <RuleReviews
              :rule="selectedRule()"
              :effective-permissions="effectivePermissions"
              :current-user-id="currentUserId"
            />
            <br />
            <RuleHistories
              :rule="selectedRule()"
              :component="component"
              :statuses="statuses"
              :severities="severities"
            />
            <br />
            <RuleSatisfactions
              :component="component"
              :rule="selectedRule()"
              :selected-rule-id="selectedRuleId"
              :project-prefix="component.prefix"
              @ruleSelected="handleRuleSelected($event)"
            />
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
import RuleSatisfactions from "./RuleSatisfactions.vue";
import SelectedRulesMixin from "../../mixins/SelectedRulesMixin.vue";

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleEditorHeader,
    RuleHistories,
    RuleReviews,
    RuleSatisfactions,
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
    severities_map: {
      type: Object,
      required: true,
    },
  },
  mounted() {
    if (this.selectedRuleId) {
      setTimeout(() => {
        this.$root.$emit("refresh:rule", this.selectedRuleId);
      }, 1);
    }
  },
};
</script>

<style scoped></style>
