<script>
/**
 * CommentIconHostMixin (PR #717)
 *
 * Mixed into the rule sub-forms (RuleForm, CheckForm, DisaRuleDescriptionForm)
 * so each one can opt in the FIRST field of each section it owns to the
 * SectionCommentIcon UX without re-implementing the prop bundle and event
 * re-emission everywhere.
 *
 * Consumer contract:
 *   - The component MUST have a `rule` prop (Object) with reviews, locked,
 *     and status keys (matches the canonical Rule shape used in Vulcan v2.x).
 *   - The component MUST have a `formGroupProps` computed returning the
 *     base bindings shared with regular RuleFormGroups.
 *
 * Usage in a sub-form:
 *   <RuleFormGroup
 *     v-bind="formGroupPropsWithCommentIcon"
 *     field-name="status"
 *     ...
 *     @open-composer="bubbleOpenComposer"
 *   />
 *
 * Other (non-first-of-section) RuleFormGroups in the same form keep using
 * `formGroupProps` so we get exactly one icon per section.
 *
 * The activation rule (Aaron 2026-04-29):
 *   - status === "Not Yet Determined" → icon visible but disabled with
 *     "Set the rule status before commenting" tooltip
 *   - rule.locked === true → icon visible but disabled with
 *     "Rule is locked — comments are closed" tooltip
 *   - otherwise → icon active
 *
 * Related app-wide UX rule (bd memory `vulcan-disabled-not-hidden`):
 *   when a feature is unavailable, render it visibly disabled with an
 *   explanatory tooltip — never hide it via v-if.
 */
export default {
  computed: {
    formGroupPropsWithCommentIcon() {
      return {
        ...this.formGroupProps,
        showCommentIcon: true,
        ruleReviews: (this.rule && this.rule.reviews) || [],
        ruleLocked: (this.rule && this.rule.locked) || false,
        ruleStatus: (this.rule && this.rule.status) || null,
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
