import { triageBgClass } from "./triageBgClass";

export function ruleHref(row, fallbackComponentId) {
  const compId = row.component_id ?? fallbackComponentId;
  return `/components/${compId}/${encodeURIComponent(row.rule_displayed_name)}`;
}

export function rowTriageClass(item) {
  return triageBgClass(item?.triage_status);
}
