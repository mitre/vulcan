import { computed } from "vue";

/**
 * Composable replacing CommentIconHostMixin. Provides the prop bundle
 * and event listeners for RuleFormGroups that host a SectionCommentIcon.
 *
 * Usage in setup(props, { emit }):
 *   const { formGroupPropsWithCommentIcon, commentIconListeners } =
 *     useCommentIconHost({ rule: toRef(props, 'rule'), formGroupProps, emit });
 *
 * Or in Options API setup() bridge (Vue 2.7):
 *   setup(props, { emit }) {
 *     const rule = toRef(props, 'rule');
 *     // formGroupProps is an options-API computed — pass a getter
 *     const formGroupProps = computed(() => this.formGroupProps);  // won't work
 *     // Instead, pass null and use formGroupPropsWithCommentIcon factory:
 *     const { commentIconListeners, commentIconProps } =
 *       useCommentIconHost({ rule, emit });
 *     return { commentIconListeners, commentIconProps };
 *   }
 *   // Then in computed: formGroupPropsWithCommentIcon uses commentIconProps
 *
 * The two-mode API:
 * 1. Full mode: pass { rule, formGroupProps, emit } — get formGroupPropsWithCommentIcon computed
 * 2. Listeners-only mode: pass { rule, emit } — get commentIconListeners + commentIconProps
 *    (consumer merges commentIconProps into their own formGroupProps computed)
 */
export function useCommentIconHost({ rule, formGroupProps, emit }) {
  const commentIconProps = computed(() => ({
    showCommentIcon: true,
    ruleReviews: (rule.value && rule.value.reviews) || [],
    ruleLocked: (rule.value && rule.value.locked) || false,
  }));

  const formGroupPropsWithCommentIcon = formGroupProps
    ? computed(() => ({ ...formGroupProps.value, ...commentIconProps.value }))
    : null;

  const commentIconListeners = {
    "open-composer": (section) => emit("open-composer", section),
    "view-comments": (section) => emit("view-comments", section),
  };

  return { formGroupPropsWithCommentIcon, commentIconListeners, commentIconProps };
}
