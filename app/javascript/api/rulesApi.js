import api from "./baseApi";

/** @param {number} ruleId @returns {Promise} */
export function getRule(ruleId) {
  return api.get(`/rules/${ruleId}`);
}

/** @param {number} ruleId @param {Object} data @returns {Promise} */
export function updateRule(ruleId, data) {
  return api.put(`/rules/${ruleId}`, { rule: data });
}

/** @param {number} ruleId @returns {Promise} */
export function deleteRule(ruleId) {
  return api.delete(`/rules/${ruleId}`);
}

/** @param {number} componentId @param {Object} ruleData @returns {Promise} */
export function createRuleInComponent(componentId, ruleData) {
  return api.post(`/components/${componentId}/rules`, { rule: ruleData });
}

/** @param {number} ruleId @param {Object} data @returns {Promise} */
export function revertRule(ruleId, data) {
  return api.post(`/rules/${ruleId}/revert`, data);
}

/** @param {number} ruleId @param {Object} data @returns {Promise} */
export function updateSectionLocks(ruleId, data) {
  return api.patch(`/rules/${ruleId}/section_locks`, data);
}

/** @param {number} ruleId @param {number} satisfiedByRuleId @returns {Promise} */
export function addSatisfaction(ruleId, satisfiedByRuleId) {
  return api.post("/rule_satisfactions", {
    rule_id: ruleId,
    satisfied_by_rule_id: satisfiedByRuleId,
  });
}

/** @param {number} ruleId @param {number} satisfiedByRuleId @returns {Promise} */
export function removeSatisfaction(ruleId, satisfiedByRuleId) {
  return api.delete(`/rule_satisfactions/${ruleId}`, {
    data: { rule_id: ruleId, satisfied_by_rule_id: satisfiedByRuleId },
  });
}

/** @param {number} componentId @returns {Promise} */
export function getRulesPicker(componentId) {
  return api.get(`/components/${componentId}/rules_picker`);
}

/** @param {number} componentId @param {string} findText @returns {Promise} */
export function findInComponent(componentId, findText) {
  return api.post(`/components/${componentId}/find`, { find: findText });
}

/** @param {number} ruleId @param {Object} ruleData @returns {Promise} */
export function duplicateRule(ruleId, ruleData) {
  return api.post(`/rules/${ruleId}/duplicate`, { rule: ruleData });
}

/** @param {number} ruleId @param {Object} data @returns {Promise} */
export function bulkSectionLocks(ruleId, data) {
  return api.patch(`/rules/${ruleId}/bulk_section_locks`, { rule: data });
}
