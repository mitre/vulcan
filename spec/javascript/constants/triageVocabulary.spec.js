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
  COMMENT_PHASE_HELP,
  CLOSED_REASON_HELP,
  commentPhaseHelpItems,
  commentPhaseStatusText,
  commentsClosedTooltip,
  sectionLabel,
  triageDisplay,
  buildStatusFilterOptions,
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

  // The settings page renders its radio options AND its help bullets from
  // these constants — one source of truth, so the two lists cannot drift.
  it("COMMENT_PHASE_HELP describes every phase", () => {
    expect(COMMENT_PHASE_HELP.open).toBe(
      "commenters can post. End date is optional — when set, it surfaces a banner with a countdown.",
    );
    expect(COMMENT_PHASE_HELP.closed).toBe(
      "commenting is paused without commitment to a workflow stage.",
    );
    expect(Object.keys(COMMENT_PHASE_HELP)).toEqual(Object.keys(COMMENT_PHASE_LABELS));
  });

  it("CLOSED_REASON_HELP describes every closed reason", () => {
    expect(CLOSED_REASON_HELP.adjudicating).toBe("window is closed but triage continues.");
    expect(CLOSED_REASON_HELP.finalized).toBe(
      "disposition published — the component is frozen for writes.",
    );
    expect(Object.keys(CLOSED_REASON_HELP)).toEqual(Object.keys(CLOSED_REASON_LABELS));
  });

  it("commentPhaseHelpItems derives one item per phase/reason state, labels via commentPhaseStatusText", () => {
    expect(commentPhaseHelpItems()).toEqual([
      {
        label: "Open",
        suffix: "",
        description:
          "commenters can post. End date is optional — when set, it surfaces a banner with a countdown.",
      },
      {
        label: "Closed (Adjudicating)",
        suffix: "",
        description: "window is closed but triage continues.",
      },
      {
        label: "Closed (Finalized)",
        suffix: "",
        description: "disposition published — the component is frozen for writes.",
      },
      {
        label: "Closed",
        suffix: " (no reason)",
        description: "commenting is paused without commitment to a workflow stage.",
      },
    ]);
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

  it("sectionLabel renders null as Overall Requirement", () => {
    expect(sectionLabel(null)).toBe("Overall Requirement");
    expect(sectionLabel(undefined)).toBe("Overall Requirement");
  });

  it("sectionLabel renders known keys via SECTION_LABELS", () => {
    expect(sectionLabel("check_content")).toBe("Check");
  });

  it("triageDisplay returns glyph + label + tooltip + cssClass", () => {
    const r = triageDisplay("concur_with_comment");
    expect(r.glyph).toBe("◐");
    expect(r.label).toBe("Accepted with Changes");
    expect(r.tooltip).toMatch(/incorporate with changes/i);
    expect(r.cssClass).toBe("triage-status--concur_with_comment");
  });

  it("freezes all the maps", () => {
    expect(Object.isFrozen(TRIAGE_LABELS)).toBe(true);
    expect(Object.isFrozen(TRIAGE_GLYPHS)).toBe(true);
  });

  describe("buildStatusFilterOptions", () => {
    it("returns 'All statuses' as first option", () => {
      const opts = buildStatusFilterOptions();
      expect(opts[0]).toEqual({ value: "all", text: "All statuses" });
    });

    it("returns 'Pending' as second option", () => {
      const opts = buildStatusFilterOptions();
      expect(opts[1]).toEqual({ value: "pending", text: "Pending" });
    });

    it("includes all non-pending TRIAGE_LABELS entries after Pending", () => {
      const opts = buildStatusFilterOptions();
      const nonPending = Object.entries(TRIAGE_LABELS).filter(([k]) => k !== "pending");
      expect(opts.length).toBe(2 + nonPending.length);
      nonPending.forEach(([value, text], i) => {
        expect(opts[2 + i]).toEqual({ value, text });
      });
    });
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
