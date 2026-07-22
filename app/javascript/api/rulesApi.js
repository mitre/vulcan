/**
 * Rule CRUD, satisfaction relationships, locking, and search API.
 * @module rulesApi
 */
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

/**
 * Revert a rule to a previous audit snapshot.
 * @param {number} ruleId
 * @param {Object} payload - `{ audit_id }` identifying which snapshot to restore.
 */
export function revertRule(ruleId, payload) {
  return api.post(`/rules/${ruleId}/revert`, payload);
}

export function updateSectionLocks(ruleId, payload) {
  return api.patch(`/rules/${ruleId}/section_locks`, payload);
}

/**
 * Create a "satisfied by" relationship: ruleId is satisfied by satisfiedByRuleId.
 * This means the child rule's requirements are covered by the parent.
 * @param {number} ruleId - The child (dependent) rule.
 * @param {number} satisfiedByRuleId - The parent rule that covers the child.
 */
export function addSatisfaction(ruleId, satisfiedByRuleId) {
  return api.post("/rule_satisfactions", {
    rule_id: ruleId,
    satisfied_by_rule_id: satisfiedByRuleId,
  });
}

/**
 * Remove a satisfaction relationship. Uses DELETE with a request body —
 * the body carries both IDs because the URL only identifies the relationship
 * record, not the direction.
 */
export function removeSatisfaction(ruleId, satisfiedByRuleId) {
  return api.delete(`/rule_satisfactions/${ruleId}`, {
    data: { rule_id: ruleId, satisfied_by_rule_id: satisfiedByRuleId },
  });
}

/**
 * Lightweight rule list for picker dropdowns (minimal fields, fast query).
 * Different from getComponentRules which returns full rule objects.
 */
export function getRulesPicker(componentId) {
  return api.get(`/components/${componentId}/rules_picker`);
}

export function findInComponent(componentId, findText) {
  return api.post(`/components/${componentId}/find`, { find: findText });
}

/**
 * Duplicate a rule within its component. Posts to the component's rules
 * create endpoint with a `duplicate: true` flag — the server copies all
 * fields from the source rule and creates a new one.
 * @param {number} componentId - Component that owns both source and copy.
 * @param {number} ruleId - Source rule to duplicate.
 */
export function duplicateRule(componentId, ruleId) {
  return api.post(`/components/${componentId}/rules`, {
    rule: { duplicate: true, id: ruleId },
  });
}

export function bulkSectionLocks(ruleId, data) {
  return api.patch(`/rules/${ruleId}/bulk_section_locks`, { rule: data });
}

/**
 * Relocation proposals: an open requirement_relocation record IS the
 * move marker for an authored SRG requirement. The receiving side
 * adjudicates — dry-run preview, accept (lands the move), or decline
 * with a required rationale. Adjudication actions are lifecycle calls:
 * flat params, not wrapped in a domain key.
 */
export function getRelocations(params = {}) {
  return api.get("/requirement_relocations", { params });
}

export function markRelocation(ruleId, targetTechnologyToken) {
  return api.post(`/rules/${ruleId}/relocations`, {
    requirement_relocation: { target_technology_token: targetTechnologyToken },
  });
}

export function unmarkRelocation(relocationId) {
  return api.delete(`/requirement_relocations/${relocationId}`);
}

export function dryRunRelocation(relocationId, targetComponentId) {
  return api.post(`/requirement_relocations/${relocationId}/dry_run`, {
    target_component_id: targetComponentId,
  });
}

export function acceptRelocation(relocationId, targetComponentId) {
  return api.post(`/requirement_relocations/${relocationId}/accept`, {
    target_component_id: targetComponentId,
  });
}

export function declineRelocation(relocationId, targetComponentId, adjudicationRationale) {
  return api.post(`/requirement_relocations/${relocationId}/decline`, {
    target_component_id: targetComponentId,
    requirement_relocation: { adjudication_rationale: adjudicationRationale },
  });
}
