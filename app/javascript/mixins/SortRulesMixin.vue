<script>
// Mixin that allows re-use of the sort function for rules
export default {
  methods: {
    // Helper to sort rules by ID
    compareRules(rule1, rule2) {
      let rule1Comp = rule1.rule_id;
      let rule2Comp = rule2.rule_id;
      if (rule1Comp < rule2Comp) {
        return -1;
      }
      if (rule1Comp > rule2Comp) {
        return 1;
      }
      return 0;
    },
  },
};
</script>
