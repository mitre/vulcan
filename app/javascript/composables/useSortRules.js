export function useSortRules() {
  function compareRules(rule1, rule2) {
    const a = rule1.rule_id;
    const b = rule2.rule_id;
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }

  return { compareRules };
}
