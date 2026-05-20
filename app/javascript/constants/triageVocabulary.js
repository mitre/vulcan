// Single source of truth for triage vocabulary in the frontend.
// Mirrors config/locales/en.yml#vulcan.triage. If you add a status key,
// update both files and the canonical table in DESIGN §3.1.2.
//
// Storage = DISA-native. UI = friendly English. See DESIGN §3.1.1 for why.

// Database / API key → friendly UI label (past tense for status display)
export const TRIAGE_LABELS = Object.freeze({
  pending: "Pending",
  concur: "Accepted",
  concur_with_comment: "Accepted with Changes",
  non_concur: "Declined",
  duplicate: "Duplicate",
  informational: "Informational",
  needs_clarification: "Needs clarification",
  withdrawn: "Withdrawn",
});

// Database / API key → DISA-matrix term (for tooltips and CSV/OSCAL export)
export const TRIAGE_DISA_LABELS = Object.freeze({
  pending: "Pending",
  concur: "Concur",
  concur_with_comment: "Concur with comment",
  non_concur: "Non-concur",
  duplicate: "Duplicate",
  informational: "Informational",
  needs_clarification: "Needs clarification",
  withdrawn: "Withdrawn",
});

// Database / API key → tooltip text (DISA term + brief explanation)
export const TRIAGE_TOOLTIPS = Object.freeze({
  pending: "Awaiting triage",
  concur: "Concur — incorporate as suggested",
  concur_with_comment: "Concur with comment — incorporate with changes",
  non_concur: "Non-concur — won't incorporate (response required)",
  duplicate: "Duplicate of another comment",
  informational: "Note acknowledged, no action required",
  needs_clarification: "Awaiting more info from commenter",
  withdrawn: "Commenter retracted this comment",
});

// Database / API key → glyph (text characters; pair with text label, never alone).
// Glyphs are decorative — always render with `aria-hidden="true"` and pair
// with the text label for screen readers (WCAG 1.4.1).
export const TRIAGE_GLYPHS = Object.freeze({
  pending: "◯",
  concur: "●",
  concur_with_comment: "◐",
  non_concur: "◑",
  duplicate: "◭",
  informational: "ⓘ",
  needs_clarification: "?",
  withdrawn: "⊘",
});

// "Closed" indicator (when adjudicated_at is set on a triaged review)
export const ADJUDICATED_LABEL = "Closed";
export const ADJUDICATED_TOOLTIP = "Adjudicated — work complete";
export const ADJUDICATED_GLYPH = "✓";

// Section vocabulary — XCCDF element keys → friendly UI label.
// Mirrors RuleConstants::SECTION_FIELDS in app/constants/rule_constants.rb.
export const SECTION_LABELS = Object.freeze({
  title: "Title",
  severity: "Severity",
  status: "Status",
  fixtext: "Fix",
  check_content: "Check",
  vuln_discussion: "Vulnerability Discussion",
  disa_metadata: "DISA Metadata",
  vendor_comments: "Vendor Comments",
  artifact_description: "Artifact Description",
  xccdf_metadata: "XCCDF Metadata",
});

// Inverse of SECTION_LABELS: friendly section display label → XCCDF key.
// Used by RuleFormGroup to translate `resolvedSection` (which returns a
// display label) into the XCCDF key that the comments API expects in
// `section`. Derived from SECTION_LABELS so the two never drift.
export const DISPLAY_TO_XCCDF_SECTION = Object.freeze(
  Object.fromEntries(Object.entries(SECTION_LABELS).map(([key, label]) => [label, key])),
);

// Component comment phase → friendly UI label.
// Two-state model: 'open' or 'closed'. The closed state may carry a
// CLOSED_REASON_LABELS value that decorates it ("Closed (Adjudicating)").
export const COMMENT_PHASE_LABELS = Object.freeze({
  open: "Open",
  closed: "Closed",
});

export const CLOSED_REASON_LABELS = Object.freeze({
  adjudicating: "Adjudicating",
  finalized: "Finalized",
});

// Render "Open" / "Closed" / "Closed (Adjudicating)" / "Closed (Finalized)".
export function commentPhaseStatusText(phase, reason) {
  const phaseLabel = COMMENT_PHASE_LABELS[phase] || phase;
  if (phase !== "closed" || !reason) return phaseLabel;
  const reasonLabel = CLOSED_REASON_LABELS[reason] || reason;
  return `${phaseLabel} (${reasonLabel})`;
}

// Tooltip copy for a disabled comment-related affordance, parameterized
// on closed_reason so the user knows WHY commenting is unavailable.
export function commentsClosedTooltip(reason) {
  if (reason === "adjudicating") {
    return "Comments are closed — the disposition is being adjudicated";
  }
  if (reason === "finalized") {
    return "Comments are closed — the disposition is finalized";
  }
  return "Comments are not enabled for this component";
}

// Helper: render the section label for a possibly-null section value
export function sectionLabel(section) {
  if (section === null || section === undefined) return "Overall Requirement";
  return SECTION_LABELS[section] || section;
}

// Statuses the server auto-adjudicates (sets adjudicated_at on save).
// Matches Ruby Review::TERMINAL_AUTO_ADJUDICATE_STATUSES exactly.
export const TERMINAL_AUTO_ADJUDICATE = new Set(["duplicate", "informational", "withdrawn"]);

// Statuses that collapse the triage form footer to a single button.
// Superset of TERMINAL_AUTO_ADJUDICATE: includes needs_clarification, which
// round-trips with the commenter (no adjudicate) but still doesn't need
// a separate "Save decision" vs "Save & close" distinction.
export const SINGLE_BUTTON_STATUSES = new Set([...TERMINAL_AUTO_ADJUDICATE, "needs_clarification"]);

// Bootstrap-Vue <b-form-select> options for triage status filters.
// "All statuses" + "Pending" first, then remaining statuses in TRIAGE_LABELS order.
export function buildStatusFilterOptions() {
  const friendly = Object.entries(TRIAGE_LABELS)
    .filter(([value]) => value !== "pending")
    .map(([value, text]) => ({ value, text }));
  return [
    { value: "all", text: "All statuses" },
    { value: "pending", text: "Pending" },
    ...friendly,
  ];
}

// Helper: triage status pair (glyph + label) for templates that need both
export function triageDisplay(status) {
  return {
    glyph: TRIAGE_GLYPHS[status] || "?",
    label: TRIAGE_LABELS[status] || status,
    tooltip: TRIAGE_TOOLTIPS[status] || "",
    cssClass: `triage-status--${status}`,
  };
}
