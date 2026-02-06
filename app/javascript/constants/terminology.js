/**
 * Centralized terminology for the application.
 *
 * This allows easy switching between terms if needed:
 * - "Rule" (XCCDF/STIG term) vs "Requirement" (SRG/business term)
 * - "Component" vs "STIG"
 *
 * Change the values here to update labels throughout the app.
 */

// Primary entity terms
export const RULE_TERM = {
  singular: "Rule",
  plural: "Rules",
  label: "Rule", // For button/panel labels like "Rule History"
};

export const BENCHMARK_TERM = {
  singular: "Benchmark",
  plural: "Benchmarks",
};

// Export file format labels (separate from document type nouns)
export const EXPORT_FORMATS = {
  xccdf: "XCCDF-Benchmark",
  csv: "CSV",
};

export const COMPONENT_TERM = {
  singular: "Component",
  plural: "Components",
  label: "Comp", // Abbreviated for button labels
  labelFull: "Component", // Full form for sidebar titles
};

// Panel button labels (used in ControlsCommandBar)
export const PANEL_LABELS = {
  // Component panels (always available)
  details: "Details",
  metadata: "Metadata",
  questions: "Questions",
  compHistory: `${COMPONENT_TERM.label} Activity`,
  compReviews: `${COMPONENT_TERM.label} Reviews`,

  // Rule panels (require selected rule)
  satisfies: "Satisfies",
  ruleHistory: `${RULE_TERM.label} History`,
  ruleReviews: `${RULE_TERM.label} Reviews`,
};

// Sidebar titles (used in ControlsSidepanels)
export const SIDEBAR_TITLES = {
  details: `${COMPONENT_TERM.labelFull} Details`,
  metadata: `${COMPONENT_TERM.labelFull} Metadata`,
  questions: "Additional Questions",
  compHistory: `${COMPONENT_TERM.labelFull} Activity`,
  compReviews: `${COMPONENT_TERM.labelFull} Reviews`,
  satisfies: "Also Satisfies",
  ruleHistory: `${RULE_TERM.singular} History`,
  ruleReviews: `${RULE_TERM.singular} Reviews`,
};

// Action labels (used in RuleActionsToolbar, modals, etc.)
export const ACTION_LABELS = {
  save: `Save ${RULE_TERM.singular}`,
  clone: `Clone ${RULE_TERM.singular}`,
  delete: `Delete ${RULE_TERM.singular}`,
  lock: `Lock ${RULE_TERM.singular}`,
  unlock: `Unlock ${RULE_TERM.singular}`,
  comment: "Comment",
  review: "Review",
  related: "Related",
};

// Navigator labels (used in RuleNavigator sidebar)
export const NAVIGATOR_LABELS = {
  openRules: `Open ${RULE_TERM.plural}`,
  allRules: `All ${RULE_TERM.plural}`,
  noRulesSelected: `No ${RULE_TERM.plural.toLowerCase()} selected`,
  searchPlaceholder: `Search ${RULE_TERM.plural.toLowerCase()}...`,
  createNew: `Create New ${RULE_TERM.singular}`,
};

// Modal/message labels (used in CommentModal, confirmations, etc.)
export const MESSAGE_LABELS = {
  // Save
  saveTitle: `Save ${RULE_TERM.singular}`,
  saveMessage: `Provide a comment that summarizes your changes to this ${RULE_TERM.singular.toLowerCase()}.`,
  // Lock/Unlock
  lockTitle: `Lock ${RULE_TERM.singular}`,
  lockMessage: `Provide a reason for locking this ${RULE_TERM.singular.toLowerCase()}.`,
  unlockTitle: `Unlock ${RULE_TERM.singular}`,
  unlockMessage: `Provide a reason for unlocking this ${RULE_TERM.singular.toLowerCase()}.`,
  // Clone/Delete
  cloneTitle: `Clone ${RULE_TERM.singular}`,
  deleteTitle: `Delete ${RULE_TERM.singular}`,
  deleteConfirmMessage: `Are you sure you want to delete this ${RULE_TERM.singular.toLowerCase()}? This cannot be undone.`,
  deleteConfirmButton: `Permanently Delete ${RULE_TERM.singular}`,
  // Comment
  commentMessage: `Submit general feedback on the ${RULE_TERM.singular.toLowerCase()}`,
  // Bulk operations
  lockAllTitle: `Lock ${COMPONENT_TERM.singular} ${RULE_TERM.plural}`,
  lockAllButton: `Lock ${RULE_TERM.plural}`,
  // Empty states
  selectRule: `Select a ${RULE_TERM.singular.toLowerCase()} on the left to view.`,
  // Validation messages
  cannotDeleteLocked: `Cannot delete a ${RULE_TERM.singular.toLowerCase()} that is locked or under review`,
  cannotSaveLocked: `Cannot save a ${RULE_TERM.singular.toLowerCase()} that is locked or under review.`,
  // Also Satisfies modal
  satisfiesPrompt: `Select ${RULE_TERM.plural.toLowerCase()} that this one satisfies:`,
  satisfiesPlaceholder: `Search and select ${RULE_TERM.plural.toLowerCase()}...`,
  // Revert history modal
  revertHistoryTitle: `Revert ${RULE_TERM.singular} History`,
};

// Role descriptions (used in NewMembership)
// Order matches available_roles: viewer, author, reviewer, admin
export const ROLE_DESCRIPTIONS = [
  `Read only access to the Project or ${COMPONENT_TERM.singular}`,
  `Edit, comment, and mark ${RULE_TERM.plural} as requiring review. Cannot sign-off or approve changes to a ${RULE_TERM.singular}. Great for individual contributors.`,
  `Author and approve changes to a ${RULE_TERM.singular}.`,
  `Full control of a Project or ${COMPONENT_TERM.singular}. Lock ${RULE_TERM.plural}, revert ${RULE_TERM.plural.toLowerCase()}, and manage members.`,
];

// Review action labels (used in RuleEditorHeader review workflow)
export const REVIEW_ACTION_LABELS = {
  requestReview: {
    name: "Request Review",
    description: `${RULE_TERM.singular.toLowerCase()} will not be editable during the review process`,
    alreadyUnderReview: `${RULE_TERM.singular} is already under review`,
    isLocked: `${RULE_TERM.singular} is currently locked`,
  },
  revokeReview: {
    name: "Revoke Review Request",
    description: `revoke your request for review - ${RULE_TERM.singular.toLowerCase()} will be editable again`,
    notAllowed: "Only an admin or the review requestor can revoke the current review request",
    notUnderReview: `${RULE_TERM.singular} is not currently under review`,
  },
  requestChanges: {
    name: "Request Changes",
    description: `request changes on the ${RULE_TERM.singular.toLowerCase()} - ${RULE_TERM.singular.toLowerCase()} will be editable again`,
    notAllowed: "Only an admin or reviewer can request changes",
    notUnderReview: `${RULE_TERM.singular} is not currently under review`,
  },
  approve: {
    name: "Approve",
    description: `approve the ${RULE_TERM.singular.toLowerCase()} - ${RULE_TERM.singular.toLowerCase()} will become locked`,
    notAllowed: "Only an admin or reviewer can approve",
    notUnderReview: `${RULE_TERM.singular} is not currently under review`,
  },
  lock: {
    name: `Lock ${RULE_TERM.singular}`,
    description: `skip the review process - ${RULE_TERM.singular.toLowerCase()} will be immediately locked`,
    notAllowed: `Only an admin can directly lock a ${RULE_TERM.singular.toLowerCase()}`,
    underReview: `Cannot lock a ${RULE_TERM.singular.toLowerCase()} that is currently under review`,
    alreadyLocked: `Cannot lock a ${RULE_TERM.singular.toLowerCase()} that is already locked`,
    mitigationRequired: `Cannot lock ${RULE_TERM.singular.toLowerCase()}: Mitigation is required for Applicable - Does Not Meet`,
    artifactRequired: `Cannot lock ${RULE_TERM.singular.toLowerCase()}: Artifact Description is required for Applicable - Inherently Meets`,
  },
  unlock: {
    name: `Unlock ${RULE_TERM.singular}`,
    description: `unlock the ${RULE_TERM.singular.toLowerCase()} - ${RULE_TERM.singular.toLowerCase()} will be editable again`,
    notAllowed: `Only an admin can unlock a ${RULE_TERM.singular.toLowerCase()}`,
    notLocked: `Cannot unlock a ${RULE_TERM.singular.toLowerCase()} that is not locked`,
  },
};

// Count label helper (e.g., "5 Rules" or "1 Rule")
export const ruleCountLabel = (count) => {
  return `${count} ${count === 1 ? RULE_TERM.singular : RULE_TERM.plural}`;
};

// Selected count label helper (e.g., "5 rules selected" or "1 rule selected")
export const selectedCountLabel = (count) => {
  const term = count === 1 ? RULE_TERM.singular.toLowerCase() : RULE_TERM.plural.toLowerCase();
  return `${count} ${term} selected`;
};

/**
 * To switch to "Requirement" terminology, change RULE_TERM to:
 *
 * export const RULE_TERM = {
 *   singular: 'Requirement',
 *   plural: 'Requirements',
 *   label: 'Req',
 * };
 */
