/**
 * Kind-safe accessor for the Rule-only array keys — satisfies,
 * satisfied_by, checks_attributes, disa_rule_descriptions_attributes.
 *
 * Requirement payloads omit array keys their kind or view does not
 * carry: the authored navigator/picker rows omit all of them, and the
 * authored editor rows omit the satisfaction graph. A missing key means
 * an empty collection, so every consumer reads through this accessor
 * instead of guarding per call site.
 */
export function ruleArray(rule, key) {
  return (rule && rule[key]) || [];
}
