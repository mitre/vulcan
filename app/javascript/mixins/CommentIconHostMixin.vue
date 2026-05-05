<script>
/**
 * Mixed into rule sub-forms (RuleForm, CheckForm, DisaRuleDescriptionForm)
 * so each one opts in the FIRST field of each section it owns to the
 * SectionCommentIcon UX without re-implementing the prop bundle and
 * event re-emission everywhere.
 *
 * Consumer contract:
 *   - The component MUST have a `rule` prop (Object) with `reviews` and
 *     `locked` keys.
 *   - The component MUST have a `formGroupProps` computed returning the
 *     base bindings shared with regular RuleFormGroups.
 *
 * Other (non-first-of-section) RuleFormGroups in the same form keep using
 * `formGroupProps` so we get exactly one icon per section.
 *
 * Activation rule:
 *   - rule.locked === true → icon visible but disabled with tooltip
 *   - component.comment_phase !== 'open' → icon visible but disabled
 *     with tooltip (component-scope, injected from the host page)
 *   - otherwise → icon active
 */
export default {
  computed: {
    formGroupPropsWithCommentIcon() {
      return {
        ...this.formGroupProps,
        showCommentIcon: true,
        ruleReviews: (this.rule && this.rule.reviews) || [],
        ruleLocked: (this.rule && this.rule.locked) || false,
      };
    },
  },
  methods: {
    bubbleOpenComposer(section) {
      this.$emit("open-composer", section);
    },
  },
};
</script>
