import api from "./baseApi";

export function getRule(ruleId) {
  return api.get(`/rules/${ruleId}`, { headers: { Accept: "application/json" } });
}

export function updateRule(ruleId, payload) {
  return api.put(`/rules/${ruleId}`, payload);
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

export function createReview(ruleId, reviewData) {
  return api.post(`/rules/${ruleId}/reviews`, reviewData);
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
  return api.get(`/components/${componentId}/rules_picker.json`);
}

export function findInComponent(componentId, findText) {
  return api.post(`/components/${componentId}/find`, { find: findText });
}

export function duplicateRule(ruleId, ruleData) {
  return api.post(`/rules/${ruleId}/duplicate`, { rule: ruleData });
}
