import { describe, it, expect } from "vitest";
import {
  TRIAGE_LABELS,
  TRIAGE_DISA_LABELS,
  TRIAGE_TOOLTIPS,
  TRIAGE_GLYPHS,
  SECTION_LABELS,
  DISPLAY_TO_XCCDF_SECTION,
  COMMENT_PHASE_LABELS,
  CLOSED_REASON_LABELS,
  commentPhaseStatusText,
  commentsClosedTooltip,
  sectionLabel,
  triageDisplay,
} from "@/constants/triageVocabulary";

const expectedStatuses = [
  "pending",
  "concur",
  "concur_with_comment",
  "non_concur",
  "duplicate",
  "informational",
  "needs_clarification",
  "withdrawn",
];

describe("triageVocabulary", () => {
  it("TRIAGE_LABELS has every expected status", () => {
    expectedStatuses.forEach((s) => expect(TRIAGE_LABELS[s]).toBeDefined());
  });

  it("TRIAGE_DISA_LABELS has every expected status", () => {
    expectedStatuses.forEach((s) => expect(TRIAGE_DISA_LABELS[s]).toBeDefined());
  });

  it("TRIAGE_TOOLTIPS has every expected status", () => {
    expectedStatuses.forEach((s) => expect(TRIAGE_TOOLTIPS[s]).toBeDefined());
  });

  it("TRIAGE_GLYPHS has every expected status", () => {
    expectedStatuses.forEach((s) => expect(TRIAGE_GLYPHS[s]).toBeDefined());
  });

  it("SECTION_LABELS covers the 10 XCCDF element keys", () => {
    const expectedSections = [
      "title",
      "severity",
      "status",
      "fixtext",
      "check_content",
      "vuln_discussion",
      "disa_metadata",
      "vendor_comments",
      "artifact_description",
      "xccdf_metadata",
    ];
    expectedSections.forEach((s) => expect(SECTION_LABELS[s]).toBeDefined());
  });

  it("COMMENT_PHASE_LABELS has open/closed", () => {
    ["open", "closed"].forEach((p) => expect(COMMENT_PHASE_LABELS[p]).toBeDefined());
  });

  it("CLOSED_REASON_LABELS has adjudicating/finalized", () => {
    ["adjudicating", "finalized"].forEach((r) => expect(CLOSED_REASON_LABELS[r]).toBeDefined());
  });

  it("commentPhaseStatusText composes the inline status badge text", () => {
    expect(commentPhaseStatusText("open", null)).toBe("Open");
    expect(commentPhaseStatusText("closed", null)).toBe("Closed");
    expect(commentPhaseStatusText("closed", "adjudicating")).toBe("Closed (Adjudicating)");
    expect(commentPhaseStatusText("closed", "finalized")).toBe("Closed (Finalized)");
  });

  it("commentsClosedTooltip varies wording by closed_reason", () => {
    expect(commentsClosedTooltip(null)).toMatch(/not enabled/i);
    expect(commentsClosedTooltip("adjudicating")).toMatch(/adjudicat/i);
    expect(commentsClosedTooltip("finalized")).toMatch(/finaliz/i);
  });

  it("sectionLabel renders null as (general)", () => {
    expect(sectionLabel(null)).toBe("(general)");
    expect(sectionLabel(undefined)).toBe("(general)");
  });

  it("sectionLabel renders known keys via SECTION_LABELS", () => {
    expect(sectionLabel("check_content")).toBe("Check");
  });

  it("triageDisplay returns glyph + label + tooltip + cssClass", () => {
    const r = triageDisplay("concur_with_comment");
    expect(r.glyph).toBe("◐");
    expect(r.label).toBe("Accept with changes");
    expect(r.tooltip).toMatch(/incorporate with changes/i);
    expect(r.cssClass).toBe("triage-status--concur_with_comment");
  });

  it("freezes all the maps", () => {
    expect(Object.isFrozen(TRIAGE_LABELS)).toBe(true);
    expect(Object.isFrozen(TRIAGE_GLYPHS)).toBe(true);
  });

  it("DISPLAY_TO_XCCDF_SECTION is the inverse of SECTION_LABELS (parity)", () => {
    Object.entries(SECTION_LABELS).forEach(([xccdfKey, displayLabel]) => {
      expect(DISPLAY_TO_XCCDF_SECTION[displayLabel]).toBe(xccdfKey);
    });
    Object.entries(DISPLAY_TO_XCCDF_SECTION).forEach(([displayLabel, xccdfKey]) => {
      expect(SECTION_LABELS[xccdfKey]).toBe(displayLabel);
    });
  });
});
