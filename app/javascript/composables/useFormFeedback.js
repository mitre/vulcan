/**
 * useFormFeedback — form feedback display helpers for Vue 2.7
 *
 * Replaces FormFeedbackMixin. Maps server-supplied feedback objects
 * (keyed by field name) to Bootstrap input state classes. Distinct from
 * useFormValidation, which generates validity from client-side rules —
 * this composable only DISPLAYS feedback handed down from the parent.
 *
 * The feedback props stay declared on the consuming component
 * (validFeedback / invalidFeedback, Object, default {}); pass the
 * reactive props object in and the helpers stay reactive because they
 * read it at call time.
 *
 * Usage:
 *   props: { validFeedback: { type: Object, default: () => ({}) },
 *            invalidFeedback: { type: Object, default: () => ({}) } },
 *   setup(props) {
 *     const { inputClass, hasValidFeedback, hasInvalidFeedback } = useFormFeedback(props);
 *     return { inputClass, hasValidFeedback, hasInvalidFeedback };
 *   }
 */
export function useFormFeedback(source) {
  // hasOwnProperty semantics (not truthiness) — a key with an empty-string
  // value still counts as feedback, matching the original mixin behavior.
  // The `|| {}` guards preserve the mixin's prop defaults for sources that
  // omit a feedback object entirely.
  function hasValidFeedback(field) {
    return Object.prototype.hasOwnProperty.call(source.validFeedback || {}, field);
  }

  function hasInvalidFeedback(field) {
    return Object.prototype.hasOwnProperty.call(source.invalidFeedback || {}, field);
  }

  // Invalid wins over valid — same precedence as the mixin.
  function inputClass(field) {
    if (hasInvalidFeedback(field)) {
      return "is-invalid";
    } else if (hasValidFeedback(field)) {
      return "is-valid";
    }
    return "";
  }

  return { inputClass, hasValidFeedback, hasInvalidFeedback };
}
