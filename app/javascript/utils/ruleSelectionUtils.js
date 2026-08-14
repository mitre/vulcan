import { ruleArray } from "./ruleArray";

export function getFirstVisibleRule(rules) {
  if (!rules || rules.length === 0) return null;

  const sortedRules = [...rules].sort((a, b) => {
    const aVersion = a.version || "";
    const bVersion = b.version || "";
    if (aVersion && bVersion) {
      return aVersion.localeCompare(bVersion);
    }
    const aId = a.rule_id || "";
    const bId = b.rule_id || "";
    return aId.localeCompare(bId);
  });

  const firstParent = sortedRules.find((r) => ruleArray(r, "satisfies").length > 0);
  if (firstParent) return firstParent;

  const firstStandalone = sortedRules.find((r) => ruleArray(r, "satisfied_by").length === 0);
  if (firstStandalone) return firstStandalone;

  return sortedRules[0];
}
