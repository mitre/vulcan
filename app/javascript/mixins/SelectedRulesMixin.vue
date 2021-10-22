<script>
// Mixin that allows re-use of the RuleNavigator rule selection code in both
// the code editor view and the read only view components.
export default {
  data: function () {
    return {
      selectedRuleId: null, // Integer for rule id
      openRuleIds: [],
    };
  },
  computed: {
    selectedRuleIdKey: function () {
      return `selectedRuleId-${this.component.id}`;
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
    handleRuleSelected: function (ruleId) {
      this.addOpenRule(ruleId);
      this.selectedRuleId = ruleId;
    },
    handleRuleDeselected: function (ruleId) {
      this.removeOpenRule(ruleId);
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
