<template>
  <div class="row">
    <div class="col-2 leftEditorColumn">
      <RuleNavigator
        :rules="rules"
        :selected-rule-id="selectedRuleId"
        :project-prefix="project.prefix"
        :project-permissions="projectPermissions"
        :openRuleIds="openRuleIds"
        @ruleSelected="handleRuleSelected($event)"
        @ruleDeselected="handleRuleDeselected($event)"
      />
    </div>

    <template v-if="selectedRule()">
      <div class="col-10">
        <RuleEditorHeader
          :rule="selectedRule()"
          :project-prefix="project.prefix"
          :project-permissions="projectPermissions"
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
              :project-permissions="projectPermissions"
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

export default {
  name: "RulesCodeEditorView",
  components: {
    RuleNavigator,
    RuleEditor,
    RuleEditorHeader,
    RuleHistories,
    RuleReviews,
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
      openRuleIds: [],
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
    openRuleIds: function (_) {
      localStorage.setItem("openRuleIds", JSON.stringify(this.openRuleIds));
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
    // Persist `openRuleIds` across page loads
    if (localStorage.getItem("openRuleIds")) {
      try {
        this.openRuleIds = JSON.parse(localStorage.getItem("openRuleIds"));
      } catch (e) {
        localStorage.removeItem("openRuleIds");
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
      this.addOpenRule(event);
      this.selectedRuleId = event;
    },
    handleRuleDeselected: function (event) {
      this.removeOpenRule(event);
    },
    // Adds a rule to the `openRules` array
    addOpenRule: function (ruleId) {
      if (this.openRuleIds.includes(ruleId)) {
        return;
      }
      this.openRuleIds.push(ruleId);
    },
    // Removes a rule from the `openRules` array
    removeOpenRule: function (ruleId) {
      const ruleIndex = this.openRuleIds.findIndex((id) => id == ruleId);
      // Guard from rule not found
      if (ruleIndex == -1) {
        return;
      }
      this.openRuleIds.splice(ruleIndex, 1);

      // Handle edge case where closed rule is the currently selected rule
      if (ruleId == this.selectedRuleId) {
        this.handleRuleSelected(null);
      }
    },
  },
};
</script>

<style scoped></style>
