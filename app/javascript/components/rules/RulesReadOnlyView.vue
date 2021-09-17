<template>
  <div class="row">
    <div class="col-3">
      <RuleNavigator
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :project-permissions="projectPermissions"
        @ruleSelected="handleRuleSelected($event)"
      />
    </div>

    <template v-if="selectedRule()">
      <div class="col-9">
        <RuleEditorHeader
          :rule="selectedRule()"
          :project-permissions="projectPermissions"
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

export default {
  name: "RulesReadOnlyView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleEditorHeader,
  },
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
  data: function () {
    return {
      selectedRuleId: null, // Integer for rule id
    };
  },
  computed: {
    selectedRuleIdKey: function () {
      return `selectedRuleId-${this.project.id}`;
    },
    lastEditor: function () {
      const histories = this.selectedRule().histories;
      if (histories.length > 0) {
        return histories[histories.length - 1].name;
      }
      return "Unknown User";
    },
  },
  watch: {
    selectedRuleId: function (_) {
      localStorage.setItem(this.selectedRuleIdKey, JSON.stringify(this.selectedRuleId));
    },
  },
  mounted: function () {
    // Persist `selectedRuleId` across page loads
    if (localStorage.getItem(this.selectedRuleIdKey)) {
      try {
        this.selectedRuleId = JSON.parse(localStorage.getItem(this.selectedRuleIdKey));
      } catch (e) {
        localStorage.removeItem(this.selectedRuleIdKey);
      }
    }
  },
  methods: {
    // This should not be a computed property because it has side effects when
    // the selected rule ID does not actually exist
    selectedRule: function () {
      const foundRule = this.rules.find((rule) => rule.id == this.selectedRuleId);
      if (foundRule) {
        return foundRule;
      }

      this.selectedRuleId = null;
      return null;
    },
    handleRuleSelected: function (event) {
      this.selectedRuleId = event;
    },
  },
};
</script>

<style scoped></style>
