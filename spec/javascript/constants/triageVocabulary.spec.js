import { describe, it, expect } from "vitest";
import {
  TRIAGE_LABELS,
  TRIAGE_DISA_LABELS,
  TRIAGE_TOOLTIPS,
  TRIAGE_GLYPHS,
  SECTION_LABELS,
  COMMENT_PHASE_LABELS,
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

  it("COMMENT_PHASE_LABELS has draft/open/adjudication/final", () => {
    ["draft", "open", "adjudication", "final"].forEach((p) =>
      expect(COMMENT_PHASE_LABELS[p]).toBeDefined(),
    );
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
});
