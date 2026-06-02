import api from "./baseApi";

export function getRule(ruleId) {
  return api.get(`/rules/${ruleId}`);
}

export function updateRule(ruleId, data) {
  return api.put(`/rules/${ruleId}`, { rule: data });
}

export function deleteRule(ruleId) {
  return api.delete(`/rules/${ruleId}`);
}

export function createRuleInComponent(componentId, ruleData) {
  return api.post(`/components/${componentId}/rules`, { rule: ruleData });
}

export function revertRule(ruleId, payload) {
  return api.post(`/rules/${ruleId}/revert`, payload);
}

export function updateSectionLocks(ruleId, payload) {
  return api.patch(`/rules/${ruleId}/section_locks`, payload);
}

export function addSatisfaction(ruleId, satisfiedByRuleId) {
  return api.post("/rule_satisfactions", {
    rule_id: ruleId,
    satisfied_by_rule_id: satisfiedByRuleId,
  });
}

export function removeSatisfaction(ruleId, satisfiedByRuleId) {
  return api.delete(`/rule_satisfactions/${ruleId}`, {
    data: { rule_id: ruleId, satisfied_by_rule_id: satisfiedByRuleId },
  });
}

export function getRulesPicker(componentId) {
  return api.get(`/components/${componentId}/rules_picker`);
}

export function findInComponent(componentId, findText) {
  return api.post(`/components/${componentId}/find`, { find: findText });
}

export function duplicateRule(componentId, ruleId) {
  return api.post(`/components/${componentId}/rules`, {
    rule: { duplicate: true, id: ruleId },
  });
}

export function bulkSectionLocks(ruleId, data) {
  return api.patch(`/rules/${ruleId}/bulk_section_locks`, { rule: data });
}
