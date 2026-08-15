/**
 * Centralized terminology for the application.
 *
 * This allows easy switching between terms if needed:
 * - "Rule" (XCCDF/STIG term) vs "Requirement" (SRG/business term)
 * - "Component" vs "STIG"
 *
 * Change the values here to update labels throughout the app.
 */

// Built-in entity terms — the fallbacks when the deployment sets no
// VULCAN_TERM_* env vars, and the only values in environments without a
// document (pure-node tests) or without the meta tag (vitest/jsdom).
const DEFAULT_RULE_TERM = Object.freeze({
  singular: "Rule",
  plural: "Rules",
  label: "Rule", // For button/panel labels like "Rule History"
});

const DEFAULT_REQUIREMENT_TERM = Object.freeze({
  singular: "Requirement",
  plural: "Requirements",
  label: "Req", // Abbreviated for button/panel labels
});

// The application layout emits Settings.terminology (the VULCAN_TERM_* env
// vars) as one meta tag on every page. It is read ONCE here — before the
// label families below are built and before any importer evaluates — so
// modules that interpolate these terms at their own init (csvColumns,
// exportConfig, ROLE_DESCRIPTIONS) see the deployment's noun without
// changes. An absent tag, malformed JSON, or a blank/non-string part each
// fall back to the built-in value for that part.
const readDeploymentTerminology = () => {
  if (typeof document === "undefined") return {};
  const tag = document.querySelector('meta[name="vulcan-terminology"]');
  if (!tag) return {};
  try {
    const parsed = JSON.parse(tag.getAttribute("content"));
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
};

const mergeTerm = (defaults, override) => {
  const merged = { ...defaults };
  for (const part of ["singular", "plural", "label"]) {
    const value = override?.[part];
    if (typeof value === "string" && value.trim() !== "") merged[part] = value;
  }
  return Object.freeze(merged);
};

const deploymentTerms = readDeploymentTerminology();

// Primary entity terms. Each kind has its own override point: a deployment
// renames every stig surface via VULCAN_TERM_STIG_*, and every srg surface
// via VULCAN_TERM_SRG_* — the kind key layers on top of the rename
// capability, never replaces it.
export const RULE_TERM = mergeTerm(DEFAULT_RULE_TERM, deploymentTerms.stig);
export const REQUIREMENT_TERM = mergeTerm(DEFAULT_REQUIREMENT_TERM, deploymentTerms.srg);

// Kind-keyed entity noun — same key set as
// STATUS_DESCRIPTIONS_BY_DOCUMENT_TYPE. Surfaces without component
// context read the deployment default (RULE_TERM) by passing nothing.
export const RULE_TERM_BY_DOCUMENT_TYPE = Object.freeze({
  stig: RULE_TERM,
  srg: REQUIREMENT_TERM,
});

export const ruleTerm = (documentType) => RULE_TERM_BY_DOCUMENT_TYPE[documentType] || RULE_TERM;

// CIS benchmarks speak in "Controls" — a viewer-only vocabulary, not a
// component kind, so it lives beside the kind terms rather than in the
// document_type map.
export const CONTROL_TERM = Object.freeze({
  singular: "Control",
  plural: "Controls",
  label: "Control",
});

// Noun resolution for the catalog/released benchmark viewers. STIG/SRG
// catalogs reuse the kind terms; a released component resolves through its
// own document_type; CIS uses CONTROL_TERM.
export const benchmarkItemTerm = (type, documentType) => {
  if (type === "cis") return CONTROL_TERM;
  if (type === "component") return ruleTerm(documentType);
  return ruleTerm(type);
};

export const BENCHMARK_TERM = {
  singular: "Benchmark",
  plural: "Benchmarks",
};

// Severity labels — single source of truth for DISA CAT mapping
// Internal values (low/medium/high) map to DISA CAT categories.
// Use SEVERITY_OPTIONS for dropdowns, SEVERITY_LABELS for display.
export const SEVERITY_LABELS = {
  high: "CAT I",
  medium: "CAT II",
  low: "CAT III",
};

// Dropdown options for b-form-select (value → display label)
export const SEVERITY_OPTIONS = Object.entries(SEVERITY_LABELS).map(([value, text]) => ({
  value,
  text,
}));

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

// Label families are BUILT from an entity term so both kinds (and any
// deployment rename of either term) stay one source of truth. Consumers
// with component context call the accessor with their document_type;
// an unknown or absent kind falls back to the deployment default.
const byDocumentType = (build) =>
  Object.freeze({ stig: build(RULE_TERM), srg: build(REQUIREMENT_TERM) });
const forKind = (map) => (documentType) => map[documentType] || map.stig;

// Panel button labels (used in ControlsCommandBar, RuleActionsToolbar)
const buildPanelLabels = (term) => ({
  // Component panels (always available)
  details: "Details",
  metadata: "Metadata",
  questions: "Questions",
  compHistory: "Changelog",

  // Requirement panels (require selected rule)
  satisfies: "Satisfies",
  ruleHistory: `${term.label} Changelog`,
  ruleReviews: `${term.label} Discussion`,
});
export const PANEL_LABELS_BY_DOCUMENT_TYPE = byDocumentType(buildPanelLabels);
export const panelLabels = forKind(PANEL_LABELS_BY_DOCUMENT_TYPE);

// Sidebar titles (used in ControlsSidepanels)
const buildSidebarTitles = (term) => ({
  details: `${COMPONENT_TERM.labelFull} Details`,
  metadata: `${COMPONENT_TERM.labelFull} Metadata`,
  questions: "Additional Questions",
  compHistory: `${COMPONENT_TERM.labelFull} Changelog`,
  satisfies: "Also Satisfies",
  ruleHistory: `${term.singular} Changelog`,
  ruleReviews: `${term.singular} Discussion`,
});
export const SIDEBAR_TITLES_BY_DOCUMENT_TYPE = byDocumentType(buildSidebarTitles);
export const sidebarTitles = forKind(SIDEBAR_TITLES_BY_DOCUMENT_TYPE);

// Per-status helper copy, keyed by document kind. The status tooltip is
// composed from the page's statuses vocabulary against this map, so a page
// can never surface another kind's status names. STIG copy is verbatim
// DISA-derived text; SRG copy follows the authoring lifecycle language.
export const STATUS_DESCRIPTIONS_BY_DOCUMENT_TYPE = Object.freeze({
  stig: {
    "Applicable - Configurable":
      "The product requires configuration or the application of policy settings to achieve compliance.",
    "Applicable - Inherently Meets":
      "The product is compliant in its initial state and cannot be subsequently reconfigured to a noncompliant state.",
    "Applicable - Does Not Meet": "There are no technical means to achieve compliance.",
    "Not Applicable":
      "The requirement addresses a capability or use case that the product does not support.",
  },
  srg: {
    Applicable:
      "The requirement applies to this technology and will be included in the released SRG.",
    "Not Applicable":
      "The requirement does not apply to this technology — a justification is required and the requirement is excluded from the released SRG.",
  },
});

// Relocation display vocabulary — the DISA-standard verb set (proposed /
// withdrawn / concur / non-concur). ONE table, read by every relocation
// surface (buttons, badges, tooltips, modal copy); an organization swaps
// its vocabulary by editing these values. Schema columns, routes, and
// state names are unaffected — this is presentation only. Requirements
// relocate between SRGs; the word "family" never appears (in this domain
// it means NIST 800-53 control families).
export const RELOCATION_TERM = {
  // Verbs and states
  propose: "Propose relocation", // source-side action (button/modal title)
  proposed: "proposed", // open-proposal state verb (count lines)
  withdraw: "Withdraw", // source-side retraction action
  concur: "Concur", // destination decision, positive
  concurConfirm: "Concur and move", // the accept modal's confirm button
  nonConcur: "Non-concur", // destination decision, negative
  nonConcurred: "Non-concurred", // retained-decline state badge

  // Destination picker ("abbreviation" is the user-facing word for the
  // SRG's short code — CTR, GPOS, DB; the API field name is unchanged)
  otherSrgOption: "Other SRG… (enter its abbreviation)",
  nextReleaseSuffix: "(next release)",

  // Titles, headings, and opener labels
  concurTitle: "Concur with relocation proposal",
  nonConcurTitle: "Non-concur with relocation proposal",
  nonConcurredHeading: "Non-concurred proposals",
  backlogTitle: "Relocation backlog",
  panelButton: "Relocations",
  panelButtonTooltip: "Relocation backlog panel",

  // Tooltip phrases
  proposeTooltip: "Propose relocating this requirement to another SRG",
  proposeInEditorTooltip: "Available in the editor — open the editor to propose relocation",
  requiresAuthorTooltip: "Requires author role",
  backlogButtonTooltip: "Relocation proposals by destination SRG",
  proposedBadgeTooltip: (token) => `Proposed for relocation to the ${token} SRG`,
  alreadyProposedTooltip: (token, viewOnlyPage) =>
    `Already proposed for relocation to the ${token} SRG — ${
      viewOnlyPage ? "open the editor to withdraw" : "withdraw from the backlog"
    }`,

  // Disabled-action reasons (backlog panel)
  selfRowReason: "This requirement already lives in this component",
  requiresAuthorReason: "Requires author role on this component",
  releasedReason: "Released components cannot receive relocated requirements",
  editorAdjudicateReason: "Open the editor to adjudicate this proposal",
  editorWithdrawReason: "Open the editor to withdraw this proposal",
  otherComponentWithdrawReason: "Withdraw from that component's editor",
};

// Navigator labels (used in the RuleList sidebar)
const buildNavigatorLabels = (term) => ({
  openRules: `Open ${term.plural}`,
  allRules: `All ${term.plural}`,
  noRulesSelected: `No ${term.plural.toLowerCase()} selected`,
  searchPlaceholder: `Search ${term.plural.toLowerCase()}...`,
  createNew: `Create New ${term.singular}`,
});
export const NAVIGATOR_LABELS_BY_DOCUMENT_TYPE = byDocumentType(buildNavigatorLabels);
export const navigatorLabels = forKind(NAVIGATOR_LABELS_BY_DOCUMENT_TYPE);

// Modal/message labels (used in CommentModal, confirmations, etc.)
const buildMessageLabels = (term) => ({
  // Save
  saveTitle: `Save ${term.singular}`,
  saveMessage: `Provide a comment that summarizes your changes to this ${term.singular.toLowerCase()}.`,
  // Lock/Unlock
  lockTitle: `Lock ${term.singular}`,
  lockMessage: `Provide a reason for locking this ${term.singular.toLowerCase()}.`,
  unlockTitle: `Unlock ${term.singular}`,
  unlockMessage: `Provide a reason for unlocking this ${term.singular.toLowerCase()}.`,
  // Clone/Delete
  cloneTitle: `Clone ${term.singular}`,
  deleteTitle: `Delete ${term.singular}`,
  deleteConfirmMessage: `Are you sure you want to delete this ${term.singular.toLowerCase()}? This cannot be undone.`,
  deleteConfirmButton: `Permanently Delete ${term.singular}`,
  // Comment
  commentMessage: `Submit general feedback on the ${term.singular.toLowerCase()}`,
  // Bulk operations
  lockAllTitle: `Lock ${COMPONENT_TERM.singular} ${term.plural}`,
  lockAllButton: `Lock ${term.plural}`,
  lockAllTooltip: `Lock all ${term.plural.toLowerCase()} in this component`,
  lockAllFullOption: `Lock all ${term.singular.toLowerCase()} fields`,
  lockAllFullHint: `Locks all fields on all unlocked ${term.plural.toLowerCase()} (existing behavior)`,
  lockSectionsHint: `Lock specific sections across all ${term.plural.toLowerCase()} while leaving other sections editable`,
  releaseRequiresLock: `All ${term.plural.toLowerCase()} must be locked to release a component`,
  // Per-rule action tooltips (RuleActionsToolbar)
  saveTooltip: `Save ${term.singular.toLowerCase()} with a comment`,
  duplicateTooltip: `Duplicate this ${term.singular.toLowerCase()}`,
  deleteTooltip: `Permanently delete this ${term.singular.toLowerCase()}`,
  unlockTooltip: `Unlock this ${term.singular.toLowerCase()} for editing`,
  lockTooltip: `Lock this ${term.singular.toLowerCase()} to prevent edits`,
  cloneTooltip: `Duplicate this ${term.singular.toLowerCase()}`,
  relatedTooltip: `View related ${term.plural.toLowerCase()} from other components`,
  satisfiesTooltip: `${term.plural} this control satisfies or is satisfied by`,
  changelogTooltip: `${term.singular} changelog — field-level changes`,
  discussionTooltip: `Comments, reviews, and triage decisions on this ${term.singular.toLowerCase()}`,
  lockedCommentsClosed: `${term.singular} is locked — comments are closed for this ${term.singular.toLowerCase()}`,
  addGeneralComment: `Add a general comment on this ${term.singular.toLowerCase()}`,
  lockedEditingDisabled: `${term.singular} is locked — editing disabled, comments still accepted`,
  lockedBadge: `${term.singular} Locked`,
  // Triage + comment-table surfaces
  prevRuleTooltip: `Previous ${term.singular.toLowerCase()}`,
  nextRuleTooltip: `Next ${term.singular.toLowerCase()}`,
  triageFilterPlaceholder: `Filter by ${term.singular.toLowerCase()} or comment...`,
  commentsByRule: `Comments by ${term.singular.toLowerCase()}`,
  moveToRule: `Move to ${term.singular.toLowerCase()}`,
  groupByRule: `Group by ${term.singular.toLowerCase()}`,
  expandCollapseRuleGroups: `Expand or collapse all ${term.singular.toLowerCase()} groups`,
  rulePickerPlaceholder: `Search by ${term.singular.toLowerCase()} ID or title...`,
  rulePickerAria: `Search target ${term.singular.toLowerCase()}`,
  dedupSearchPlaceholder: `Search by author, ${term.singular.toLowerCase()}, or comment text...`,
  // Spreadsheet update modal
  spreadsheetTitle: `Update ${term.plural} from Spreadsheet`,
  updatedRules: `Updated ${term.plural}`,
  unchangedRules: `Unchanged ${term.plural}`,
  protectedRules: `Protected ${term.plural} (Skipped)`,
  rulesUpdated: `${term.plural} updated successfully.`,
  // Section-scope label for whole-requirement comments (vs a named section)
  overallSection: `Overall ${term.singular}`,
  // Empty states
  selectRule: `Select a ${term.singular.toLowerCase()} on the left to view.`,
  // Validation messages
  cannotDeleteLocked: `Cannot delete a ${term.singular.toLowerCase()} that is locked or under review`,
  cannotSaveLocked: `Cannot save a ${term.singular.toLowerCase()} that is locked or under review.`,
  // Also Satisfies modal (a STIG-only surface — its consumer passes "stig")
  satisfiesPrompt: `Select SRG requirements that this ${term.singular.toLowerCase()} satisfies:`,
  satisfiesPlaceholder: `Search and select SRG requirements...`,
  // Revert history modal
  revertHistoryTitle: `Revert ${term.singular} History`,
});
export const MESSAGE_LABELS_BY_DOCUMENT_TYPE = byDocumentType(buildMessageLabels);
export const messageLabels = forKind(MESSAGE_LABELS_BY_DOCUMENT_TYPE);

// Review action descriptions — maps review action strings to display labels.
// Used in RulesCodeEditorView, ProjectComponent, RuleReviews.
export const ACTION_DESCRIPTIONS = {
  comment: "Commented",
  request_review: "Requested Review",
  revoke_review_request: "Revoked Request for Review",
  request_changes: "Requested Changes",
  approve: "Approved",
  lock_control: "Locked",
  unlock_control: "Unlocked",
};

// Role descriptions (used in NewMembership)
// Order matches available_roles: viewer, author, reviewer, admin
export const ROLE_DESCRIPTIONS = [
  `Read access to the Project or ${COMPONENT_TERM.singular}, plus the ability to leave comments during a public comment window.`,
  `Edit content and mark ${RULE_TERM.plural} as requiring review. Can also triage incoming comments. Cannot sign off on review requests. Great for individual contributors.`,
  `Author and approve changes to a ${RULE_TERM.singular}.`,
  `Full control of a Project or ${COMPONENT_TERM.singular}. Lock ${RULE_TERM.plural}, revert ${RULE_TERM.plural.toLowerCase()}, and manage members.`,
];

// Review action labels (used by reviewActionHelpers for the review workflow)
const buildReviewActionLabels = (term) => ({
  requestReview: {
    name: "Request Review",
    description: `${term.singular.toLowerCase()} will not be editable during the review process`,
    alreadyUnderReview: `${term.singular} is already under review`,
    isLocked: `${term.singular} is currently locked`,
  },
  revokeReview: {
    name: "Revoke Review Request",
    description: `revoke your request for review - ${term.singular.toLowerCase()} will be editable again`,
    notAllowed: "Only an admin or the review requestor can revoke the current review request",
    notUnderReview: `${term.singular} is not currently under review`,
  },
  requestChanges: {
    name: "Request Changes",
    description: `request changes on the ${term.singular.toLowerCase()} - ${term.singular.toLowerCase()} will be editable again`,
    notAllowed: "Only an admin or reviewer can request changes",
    notUnderReview: `${term.singular} is not currently under review`,
  },
  approve: {
    name: "Approve",
    description: `approve the ${term.singular.toLowerCase()} - ${term.singular.toLowerCase()} will become locked`,
    notAllowed: "Only an admin or reviewer can approve",
    notUnderReview: `${term.singular} is not currently under review`,
  },
  lock: {
    name: `Lock ${term.singular}`,
    description: `skip the review process - ${term.singular.toLowerCase()} will be immediately locked`,
    notAllowed: `Only an admin can directly lock a ${term.singular.toLowerCase()}`,
    underReview: `Cannot lock a ${term.singular.toLowerCase()} that is currently under review`,
    alreadyLocked: `Cannot lock a ${term.singular.toLowerCase()} that is already locked`,
    mitigationRequired: `Cannot lock ${term.singular.toLowerCase()}: Mitigation is required for Applicable - Does Not Meet`,
    artifactRequired: `Cannot lock ${term.singular.toLowerCase()}: Artifact Description is required for Applicable - Inherently Meets`,
  },
  unlock: {
    name: `Unlock ${term.singular}`,
    description: `unlock the ${term.singular.toLowerCase()} - ${term.singular.toLowerCase()} will be editable again`,
    notAllowed: `Only an admin can unlock a ${term.singular.toLowerCase()}`,
    notLocked: `Cannot unlock a ${term.singular.toLowerCase()} that is not locked`,
  },
});
export const REVIEW_ACTION_LABELS_BY_DOCUMENT_TYPE = byDocumentType(buildReviewActionLabels);
export const reviewActionLabels = forKind(REVIEW_ACTION_LABELS_BY_DOCUMENT_TYPE);

// Count label helper (e.g., "5 Rules", "1 Requirement"); the kind is
// optional — surfaces without component context get the deployment noun.
export const ruleCountLabel = (count, documentType) => {
  const term = ruleTerm(documentType);
  return `${count} ${count === 1 ? term.singular : term.plural}`;
};

// Selected count label helper (e.g., "5 rules selected")
export const selectedCountLabel = (count, documentType) => {
  const term = ruleTerm(documentType);
  const noun = count === 1 ? term.singular.toLowerCase() : term.plural.toLowerCase();
  return `${count} ${noun} selected`;
};
