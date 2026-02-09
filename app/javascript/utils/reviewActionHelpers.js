/**
 * Shared helper for computing review action disabled tooltips.
 *
 * Used by RuleReviewDropdown and RuleReviewModal to determine which
 * review actions are available and why disabled ones are disabled.
 *
 * Each function returns a tooltip string (action is disabled) or null (action is enabled).
 */

import { REVIEW_ACTION_LABELS } from "../constants/terminology";

/**
 * Determine the disabled tooltip for "Request Review".
 *
 * Disabled when:
 * - The rule is already under review
 * - The rule is locked
 */
function requestReviewTooltip(rule, isUnderReview) {
  const labels = REVIEW_ACTION_LABELS.requestReview;

  if (isUnderReview) {
    return labels.alreadyUnderReview;
  }
  if (rule.locked) {
    return labels.isLocked;
  }
  return null;
}

/**
 * Determine the disabled tooltip for "Revoke Review Request".
 *
 * Disabled when:
 * - The user is not an admin or the original requestor
 * - The rule is not currently under review
 */
function revokeReviewTooltip(isAdmin, isRequestor, isUnderReview) {
  const labels = REVIEW_ACTION_LABELS.revokeReview;

  if (!(isAdmin || isRequestor)) {
    return labels.notAllowed;
  }
  if (isUnderReview) {
    return null;
  }
  return labels.notUnderReview;
}

/**
 * Determine the disabled tooltip for "Request Changes".
 *
 * Disabled when:
 * - The user is not an admin or reviewer
 * - The rule is not currently under review
 */
function requestChangesTooltip(isAdmin, isReviewer, isUnderReview) {
  const labels = REVIEW_ACTION_LABELS.requestChanges;

  if (!(isAdmin || isReviewer)) {
    return labels.notAllowed;
  }
  if (isUnderReview) {
    return null;
  }
  return labels.notUnderReview;
}

/**
 * Determine the disabled tooltip for "Approve".
 *
 * Disabled when:
 * - The user is not an admin or reviewer
 * - The rule is not currently under review
 */
function approveTooltip(isAdmin, isReviewer, isUnderReview) {
  const labels = REVIEW_ACTION_LABELS.approve;

  if (!(isAdmin || isReviewer)) {
    return labels.notAllowed;
  }
  if (isUnderReview) {
    return null;
  }
  return labels.notUnderReview;
}

/**
 * Determine the disabled tooltip for "Lock Control".
 *
 * Disabled when:
 * - The user is not an admin
 * - The rule is under review
 * - The rule is already locked
 * - Status is "Applicable - Does Not Meet" with no mitigations
 * - Status is "Applicable - Inherently Meets" with no artifact description
 */
function lockControlTooltip(rule, isAdmin, isUnderReview) {
  const labels = REVIEW_ACTION_LABELS.lock;

  if (!isAdmin) {
    return labels.notAllowed;
  }
  if (isUnderReview) {
    return labels.underReview;
  }
  if (rule.locked) {
    return labels.alreadyLocked;
  }

  const hasMissingMitigation =
    rule.status === "Applicable - Does Not Meet" &&
    rule.disa_rule_descriptions_attributes?.[0]?.mitigations?.length === 0;

  if (hasMissingMitigation) {
    return labels.mitigationRequired;
  }

  const hasMissingArtifact =
    rule.status === "Applicable - Inherently Meets" &&
    (!rule.artifact_description || rule.artifact_description.length === 0);

  if (hasMissingArtifact) {
    return labels.artifactRequired;
  }

  return null;
}

/**
 * Determine the disabled tooltip for "Unlock Control".
 *
 * Disabled when:
 * - The user is not an admin
 * - The rule is not currently locked
 */
function unlockControlTooltip(rule, isAdmin) {
  const labels = REVIEW_ACTION_LABELS.unlock;

  if (!isAdmin) {
    return labels.notAllowed;
  }
  if (rule.locked) {
    return null;
  }
  return labels.notLocked;
}

/**
 * Build the full review actions array for a rule.
 *
 * @param {Object} rule - The rule object
 * @param {boolean} readOnly - Whether the current user has read-only access
 * @param {string} effectivePermissions - "admin", "reviewer", or other
 * @param {number} currentUserId - The current user's ID
 * @returns {Array} Array of review action objects with value, name, description, disabledTooltip
 */
export function buildReviewActions(rule, readOnly, effectivePermissions, currentUserId) {
  const isAdmin = !readOnly && effectivePermissions === "admin";
  const isReviewer = !readOnly && effectivePermissions === "reviewer";
  const isRequestor = !readOnly && currentUserId === rule.review_requestor_id;
  const isUnderReview = rule.review_requestor_id != null;
  const labels = REVIEW_ACTION_LABELS;

  return [
    {
      value: "request_review",
      name: labels.requestReview.name,
      description: labels.requestReview.description,
      disabledTooltip: requestReviewTooltip(rule, isUnderReview),
    },
    {
      value: "revoke_review_request",
      name: labels.revokeReview.name,
      description: labels.revokeReview.description,
      disabledTooltip: revokeReviewTooltip(isAdmin, isRequestor, isUnderReview),
    },
    {
      value: "request_changes",
      name: labels.requestChanges.name,
      description: labels.requestChanges.description,
      disabledTooltip: requestChangesTooltip(isAdmin, isReviewer, isUnderReview),
    },
    {
      value: "approve",
      name: labels.approve.name,
      description: labels.approve.description,
      disabledTooltip: approveTooltip(isAdmin, isReviewer, isUnderReview),
    },
    {
      value: "lock_control",
      name: labels.lock.name,
      description: labels.lock.description,
      disabledTooltip: lockControlTooltip(rule, isAdmin, isUnderReview),
    },
    {
      value: "unlock_control",
      name: labels.unlock.name,
      description: labels.unlock.description,
      disabledTooltip: unlockControlTooltip(rule, isAdmin),
    },
  ];
}
