import { describe, it, expect, vi, afterEach } from "vitest";
import {
  RULE_TERM,
  REQUIREMENT_TERM,
  RULE_TERM_BY_DOCUMENT_TYPE,
  STATUS_DESCRIPTIONS_BY_DOCUMENT_TYPE,
  ruleTerm,
  COMPONENT_TERM,
  ROLE_DESCRIPTIONS,
  SEVERITY_LABELS,
  SEVERITY_OPTIONS,
  navigatorLabels,
  messageLabels,
  panelLabels,
  sidebarTitles,
  reviewActionLabels,
  ruleCountLabel,
  selectedCountLabel,
} from "@/constants/terminology";

// The stig instances are the deployment defaults — the pre-existing DRY
// assertions below verify each family derives from RULE_TERM through them.
const PANEL_LABELS = panelLabels("stig");
const SIDEBAR_TITLES = sidebarTitles("stig");
const NAVIGATOR_LABELS = navigatorLabels("stig");
const MESSAGE_LABELS = messageLabels("stig");
const REVIEW_ACTION_LABELS = reviewActionLabels("stig");

/**
 * Terminology Constants Tests
 *
 * These tests ensure the terminology configuration is properly structured
 * and that all labels are derived from the base terms (DRY principle).
 *
 * If terminology changes (e.g., "Rule" → "Requirement"), these tests
 * verify the change propagates correctly throughout the app.
 */
describe("kind-keyed entity nouns", () => {
  it("ruleCountLabel keys the noun by document_type", () => {
    expect(ruleCountLabel(3, "srg")).toBe("3 Requirements");
    expect(ruleCountLabel(1, "srg")).toBe("1 Requirement");
    expect(ruleCountLabel(3, "stig")).toBe(`3 ${RULE_TERM.plural}`);
  });

  it("defaults to the deployment noun when no kind is given", () => {
    expect(ruleCountLabel(2)).toBe(`2 ${RULE_TERM.plural}`);
    expect(selectedCountLabel(2)).toBe(`2 ${RULE_TERM.plural.toLowerCase()} selected`);
  });

  it("ruleTerm keys by document_type with the same key set as the status map", () => {
    expect(Object.keys(RULE_TERM_BY_DOCUMENT_TYPE).sort()).toEqual(
      Object.keys(STATUS_DESCRIPTIONS_BY_DOCUMENT_TYPE).sort(),
    );
    expect(ruleTerm("srg")).toBe(REQUIREMENT_TERM);
    expect(ruleTerm("stig")).toBe(RULE_TERM);
    expect(ruleTerm(undefined)).toBe(RULE_TERM);
  });

  it("deployment-wide rename composes with the kind key (regression pin)", () => {
    // stig labels derive from RULE_TERM — the deployment override point —
    // so editing RULE_TERM still renames every stig surface; srg labels
    // derive from REQUIREMENT_TERM, its own override point.
    expect(navigatorLabels("stig").openRules).toBe(`Open ${RULE_TERM.plural}`);
    expect(navigatorLabels("srg").openRules).toBe(`Open ${REQUIREMENT_TERM.plural}`);
    // Literal pins on BOTH sides — the derived comparisons alone would pass
    // if a builder hardcoded its noun.
    expect(navigatorLabels("stig").openRules).toBe("Open Rules");
    expect(navigatorLabels("srg").openRules).toBe("Open Requirements");
  });

  it("label families key by kind", () => {
    expect(messageLabels("srg").saveTitle).toBe("Save Requirement");
    expect(messageLabels("stig").saveTitle).toBe(`Save ${RULE_TERM.singular}`);
    expect(panelLabels("srg").ruleHistory).toBe(`${REQUIREMENT_TERM.label} Changelog`);
    expect(sidebarTitles("srg").ruleHistory).toBe("Requirement Changelog");
    expect(reviewActionLabels("srg").lock.name).toBe("Lock Requirement");
    expect(reviewActionLabels("stig").lock.name).toBe(`Lock ${RULE_TERM.singular}`);
    expect(selectedCountLabel(2, "srg")).toBe("2 requirements selected");
  });

  it("tooltip/triage/table keys carry the kind noun", () => {
    expect(messageLabels("srg").lockedBadge).toBe("Requirement Locked");
    expect(messageLabels("srg").groupByRule).toBe("Group by requirement");
    expect(messageLabels("srg").moveToRule).toBe("Move to requirement");
    expect(messageLabels("srg").prevRuleTooltip).toBe("Previous requirement");
    expect(messageLabels("srg").spreadsheetTitle).toBe("Update Requirements from Spreadsheet");
    expect(messageLabels("srg").releaseRequiresLock).toBe(
      "All requirements must be locked to release a component",
    );
    expect(messageLabels("stig").lockedBadge).toBe(`${RULE_TERM.singular} Locked`);
    expect(messageLabels("stig").groupByRule).toBe(`Group by ${RULE_TERM.singular.toLowerCase()}`);
  });

  it("benchmarkItemTerm resolves viewer nouns through the central table", async () => {
    const { benchmarkItemTerm, CONTROL_TERM } = await import("@/constants/terminology");
    expect(benchmarkItemTerm("stig")).toBe(RULE_TERM);
    expect(benchmarkItemTerm("srg")).toBe(REQUIREMENT_TERM);
    expect(benchmarkItemTerm("cis")).toBe(CONTROL_TERM);
    expect(benchmarkItemTerm("component", "srg")).toBe(REQUIREMENT_TERM);
    expect(benchmarkItemTerm("component", "stig")).toBe(RULE_TERM);
    expect(benchmarkItemTerm("component", undefined)).toBe(RULE_TERM);
  });

  it("no srg-kind label in any family contains the bare rule noun", () => {
    // The family-level guard: every srg string must speak in Requirement
    // terms. A newly added key with a hardcoded "rule" fails here without
    // needing a per-key assertion.
    const flatten = (value) =>
      typeof value === "string" ? [value] : Object.values(value).flatMap(flatten);
    const srgStrings = [
      messageLabels("srg"),
      panelLabels("srg"),
      sidebarTitles("srg"),
      navigatorLabels("srg"),
      reviewActionLabels("srg"),
    ].flatMap(flatten);
    expect(srgStrings.length).toBeGreaterThan(50);
    for (const s of srgStrings) {
      expect(s).not.toMatch(/\brules?\b/i);
    }
  });
});

describe("terminology constants", () => {
  describe("RULE_TERM", () => {
    it("has required properties", () => {
      expect(RULE_TERM).toHaveProperty("singular");
      expect(RULE_TERM).toHaveProperty("plural");
      expect(RULE_TERM).toHaveProperty("label");
    });

    it("singular and plural are consistent", () => {
      // If singular is "Rule", plural should be "Rules"
      // If singular is "Requirement", plural should be "Requirements"
      expect(RULE_TERM.plural).toBe(`${RULE_TERM.singular}s`);
    });
  });

  describe("COMPONENT_TERM", () => {
    it("has required properties", () => {
      expect(COMPONENT_TERM).toHaveProperty("singular");
      expect(COMPONENT_TERM).toHaveProperty("plural");
      expect(COMPONENT_TERM).toHaveProperty("label");
      expect(COMPONENT_TERM).toHaveProperty("labelFull");
    });

    it("labelFull matches singular", () => {
      expect(COMPONENT_TERM.labelFull).toBe(COMPONENT_TERM.singular);
    });
  });

  describe("PANEL_LABELS", () => {
    it("has all required panel labels", () => {
      expect(PANEL_LABELS).toHaveProperty("details");
      expect(PANEL_LABELS).toHaveProperty("metadata");
      expect(PANEL_LABELS).toHaveProperty("questions");
      expect(PANEL_LABELS).toHaveProperty("compHistory");
      // compReviews retired in PR #717 — slideover replaced by full-page
      // /components/:id/triage route. The Triage button on the command
      // bar links there instead of toggling a panel.
      expect(PANEL_LABELS).toHaveProperty("satisfies");
      expect(PANEL_LABELS).toHaveProperty("ruleHistory");
      expect(PANEL_LABELS).toHaveProperty("ruleReviews");
    });

    it("component panel labels are concise (no prefix)", () => {
      expect(PANEL_LABELS.compHistory).toBe("Changelog");
    });

    it("rule labels use RULE_TERM.label", () => {
      expect(PANEL_LABELS.ruleHistory).toContain(RULE_TERM.label);
      expect(PANEL_LABELS.ruleReviews).toContain(RULE_TERM.label);
    });
  });

  describe("SIDEBAR_TITLES", () => {
    it("has all required sidebar titles", () => {
      expect(SIDEBAR_TITLES).toHaveProperty("details");
      expect(SIDEBAR_TITLES).toHaveProperty("metadata");
      expect(SIDEBAR_TITLES).toHaveProperty("questions");
      expect(SIDEBAR_TITLES).toHaveProperty("compHistory");
      // compReviews retired with the slideover.
      expect(SIDEBAR_TITLES).toHaveProperty("satisfies");
      expect(SIDEBAR_TITLES).toHaveProperty("ruleHistory");
      expect(SIDEBAR_TITLES).toHaveProperty("ruleReviews");
    });

    it("component sidebar titles use COMPONENT_TERM.labelFull", () => {
      expect(SIDEBAR_TITLES.details).toContain(COMPONENT_TERM.labelFull);
      expect(SIDEBAR_TITLES.metadata).toContain(COMPONENT_TERM.labelFull);
      expect(SIDEBAR_TITLES.compHistory).toContain(COMPONENT_TERM.labelFull);
    });

    it("rule sidebar titles use RULE_TERM.singular", () => {
      expect(SIDEBAR_TITLES.ruleHistory).toContain(RULE_TERM.singular);
      expect(SIDEBAR_TITLES.ruleReviews).toContain(RULE_TERM.singular);
    });
  });

  describe("NAVIGATOR_LABELS", () => {
    it("has all required navigator labels", () => {
      expect(NAVIGATOR_LABELS).toHaveProperty("openRules");
      expect(NAVIGATOR_LABELS).toHaveProperty("allRules");
      expect(NAVIGATOR_LABELS).toHaveProperty("noRulesSelected");
      expect(NAVIGATOR_LABELS).toHaveProperty("searchPlaceholder");
      expect(NAVIGATOR_LABELS).toHaveProperty("createNew");
    });

    it("navigator labels use RULE_TERM", () => {
      expect(NAVIGATOR_LABELS.openRules).toContain(RULE_TERM.plural);
      expect(NAVIGATOR_LABELS.allRules).toContain(RULE_TERM.plural);
      expect(NAVIGATOR_LABELS.createNew).toContain(RULE_TERM.singular);
    });

    it("search placeholder uses lowercase plural", () => {
      expect(NAVIGATOR_LABELS.searchPlaceholder.toLowerCase()).toContain(
        RULE_TERM.plural.toLowerCase(),
      );
    });
  });

  describe("MESSAGE_LABELS", () => {
    it("has all required message labels", () => {
      expect(MESSAGE_LABELS).toHaveProperty("saveTitle");
      expect(MESSAGE_LABELS).toHaveProperty("saveMessage");
      expect(MESSAGE_LABELS).toHaveProperty("lockTitle");
      expect(MESSAGE_LABELS).toHaveProperty("lockMessage");
      expect(MESSAGE_LABELS).toHaveProperty("unlockTitle");
      expect(MESSAGE_LABELS).toHaveProperty("unlockMessage");
      expect(MESSAGE_LABELS).toHaveProperty("cloneTitle");
      expect(MESSAGE_LABELS).toHaveProperty("deleteTitle");
      expect(MESSAGE_LABELS).toHaveProperty("commentMessage");
      expect(MESSAGE_LABELS).toHaveProperty("selectRule");
      // Delete confirmation
      expect(MESSAGE_LABELS).toHaveProperty("deleteConfirmMessage");
      expect(MESSAGE_LABELS).toHaveProperty("deleteConfirmButton");
      // Also Satisfies modal
      expect(MESSAGE_LABELS).toHaveProperty("satisfiesPrompt");
      expect(MESSAGE_LABELS).toHaveProperty("satisfiesPlaceholder");
      // Revert history
      expect(MESSAGE_LABELS).toHaveProperty("revertHistoryTitle");
    });

    it("revert history title uses RULE_TERM", () => {
      expect(MESSAGE_LABELS.revertHistoryTitle).toContain(RULE_TERM.singular);
    });

    it("delete confirmation uses RULE_TERM", () => {
      expect(MESSAGE_LABELS.deleteConfirmMessage.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(MESSAGE_LABELS.deleteConfirmButton).toContain(RULE_TERM.singular);
    });

    it("satisfies labels use SRG requirements terminology", () => {
      // Satisfaction relationships are semantically about SRG requirements, not rules
      expect(MESSAGE_LABELS.satisfiesPrompt.toLowerCase()).toContain("srg requirements");
      expect(MESSAGE_LABELS.satisfiesPlaceholder.toLowerCase()).toContain("srg requirements");
    });

    it("message labels use RULE_TERM", () => {
      expect(MESSAGE_LABELS.saveTitle).toContain(RULE_TERM.singular);
      expect(MESSAGE_LABELS.lockTitle).toContain(RULE_TERM.singular);
      expect(MESSAGE_LABELS.unlockTitle).toContain(RULE_TERM.singular);
      expect(MESSAGE_LABELS.cloneTitle).toContain(RULE_TERM.singular);
      expect(MESSAGE_LABELS.deleteTitle).toContain(RULE_TERM.singular);
    });

    it("message bodies use lowercase rule term", () => {
      expect(MESSAGE_LABELS.saveMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase());
      expect(MESSAGE_LABELS.lockMessage.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase());
      expect(MESSAGE_LABELS.commentMessage.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
    });
  });

  describe("ROLE_DESCRIPTIONS", () => {
    it("has all four role descriptions", () => {
      expect(ROLE_DESCRIPTIONS).toHaveLength(4);
    });

    it("role descriptions that mention rules use RULE_TERM", () => {
      // Author and reviewer roles mention rules
      const authorDesc = ROLE_DESCRIPTIONS[1]; // author role
      const reviewerDesc = ROLE_DESCRIPTIONS[2]; // reviewer role
      const adminDesc = ROLE_DESCRIPTIONS[3]; // admin role

      // These descriptions should use RULE_TERM, not "Control"
      expect(authorDesc.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase());
      expect(reviewerDesc.toLowerCase()).toContain(RULE_TERM.singular.toLowerCase());
      expect(adminDesc.toLowerCase()).toContain(RULE_TERM.plural.toLowerCase());
    });

    it('does not contain hardcoded "Control" or "Controls" as entity name', () => {
      // Check for "Control" or "Controls" when used as the entity name (not the verb "control")
      // The pattern matches: "a Control", "the Control", "Controls" at word boundary
      // but NOT "Full control" (lowercase verb usage)
      ROLE_DESCRIPTIONS.forEach((desc) => {
        expect(desc).not.toMatch(/\bControls\b/); // Plural always refers to entity
        expect(desc).not.toMatch(/\ba Control\b/i); // "a Control" is entity reference
        expect(desc).not.toMatch(/\bthe Control\b/i); // "the Control" is entity reference
      });
    });
  });

  describe("REVIEW_ACTION_LABELS", () => {
    it("has all required review action labels", () => {
      expect(REVIEW_ACTION_LABELS).toHaveProperty("requestReview");
      expect(REVIEW_ACTION_LABELS).toHaveProperty("revokeReview");
      expect(REVIEW_ACTION_LABELS).toHaveProperty("requestChanges");
      expect(REVIEW_ACTION_LABELS).toHaveProperty("approve");
      expect(REVIEW_ACTION_LABELS).toHaveProperty("lock");
      expect(REVIEW_ACTION_LABELS).toHaveProperty("unlock");
    });

    it("review action descriptions use RULE_TERM", () => {
      // All action descriptions should reference the rule term, not "control"
      expect(REVIEW_ACTION_LABELS.requestReview.description.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(REVIEW_ACTION_LABELS.approve.description.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(REVIEW_ACTION_LABELS.lock.description.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(REVIEW_ACTION_LABELS.unlock.description.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
    });

    it("disabled tooltips use RULE_TERM", () => {
      // All tooltips mentioning the entity should use the correct term
      expect(REVIEW_ACTION_LABELS.requestReview.alreadyUnderReview.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(REVIEW_ACTION_LABELS.lock.alreadyLocked.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
      expect(REVIEW_ACTION_LABELS.unlock.notLocked.toLowerCase()).toContain(
        RULE_TERM.singular.toLowerCase(),
      );
    });
  });

  describe("ruleCountLabel helper", () => {
    it("returns singular for count of 1", () => {
      expect(ruleCountLabel(1)).toBe(`1 ${RULE_TERM.singular}`);
    });

    it("returns plural for count of 0", () => {
      expect(ruleCountLabel(0)).toBe(`0 ${RULE_TERM.plural}`);
    });

    it("returns plural for count greater than 1", () => {
      expect(ruleCountLabel(5)).toBe(`5 ${RULE_TERM.plural}`);
      expect(ruleCountLabel(100)).toBe(`100 ${RULE_TERM.plural}`);
    });
  });

  describe("selectedCountLabel helper", () => {
    it("returns singular for count of 1", () => {
      expect(selectedCountLabel(1)).toBe(`1 ${RULE_TERM.singular.toLowerCase()} selected`);
    });

    it("returns plural for count of 0", () => {
      expect(selectedCountLabel(0)).toBe(`0 ${RULE_TERM.plural.toLowerCase()} selected`);
    });

    it("returns plural for count greater than 1", () => {
      expect(selectedCountLabel(5)).toBe(`5 ${RULE_TERM.plural.toLowerCase()} selected`);
    });
  });

  // REGRESSION: Session 169 — SEVERITIES array contained "unknown" and "info"
  // from InSpec integration (2021). These are NOT valid DISA STIG severities.
  // Only CAT I (high), CAT II (medium), CAT III (low) are valid.
  describe("SEVERITY_LABELS", () => {
    it("maps only valid DISA severity values", () => {
      expect(Object.keys(SEVERITY_LABELS)).toEqual(["high", "medium", "low"]);
    });

    it("uses DISA CAT category labels", () => {
      expect(SEVERITY_LABELS.high).toBe("CAT I");
      expect(SEVERITY_LABELS.medium).toBe("CAT II");
      expect(SEVERITY_LABELS.low).toBe("CAT III");
    });

    it('does NOT contain "unknown" or "info" (regression: InSpec values)', () => {
      expect(SEVERITY_LABELS).not.toHaveProperty("unknown");
      expect(SEVERITY_LABELS).not.toHaveProperty("info");
    });
  });

  describe("SEVERITY_OPTIONS (dropdown)", () => {
    it("has exactly 3 options for b-form-select", () => {
      expect(SEVERITY_OPTIONS).toHaveLength(3);
    });

    it("each option has value and text properties", () => {
      SEVERITY_OPTIONS.forEach((opt) => {
        expect(opt).toHaveProperty("value");
        expect(opt).toHaveProperty("text");
      });
    });

    it("maps internal values to CAT display labels", () => {
      const values = SEVERITY_OPTIONS.map((o) => o.value);
      const texts = SEVERITY_OPTIONS.map((o) => o.text);

      expect(values).toContain("high");
      expect(values).toContain("medium");
      expect(values).toContain("low");
      expect(texts).toContain("CAT I");
      expect(texts).toContain("CAT II");
      expect(texts).toContain("CAT III");
    });

    it('does NOT contain "unknown" or "info" options (regression)', () => {
      const values = SEVERITY_OPTIONS.map((o) => o.value);
      expect(values).not.toContain("unknown");
      expect(values).not.toContain("info");
    });
  });

  describe("DRY principle verification", () => {
    it("changing RULE_TERM would update all derived labels", () => {
      const expectedRuleHistoryPattern = new RegExp(`${RULE_TERM.label}.*Changelog`);
      const expectedRuleDiscussionPattern = new RegExp(`${RULE_TERM.label}.*Discussion`);

      expect(PANEL_LABELS.ruleHistory).toMatch(expectedRuleHistoryPattern);
      expect(PANEL_LABELS.ruleReviews).toMatch(expectedRuleDiscussionPattern);
    });

    it("component panel labels are independent of COMPONENT_TERM", () => {
      expect(PANEL_LABELS.compHistory).not.toContain(COMPONENT_TERM.label);
    });
  });

  describe("deployment terminology overrides (vulcan-terminology meta tag)", () => {
    // The layout emits Settings.terminology as one meta tag; terminology.js
    // reads it once at module init, so overrides must be exercised on a
    // FRESH module instance (resetModules + dynamic import).
    const removeTag = () =>
      document.head.querySelectorAll('meta[name="vulcan-terminology"]').forEach((t) => t.remove());

    const importWithMetaTag = async (content) => {
      vi.resetModules();
      removeTag();
      if (content !== null) {
        const tag = document.createElement("meta");
        tag.setAttribute("name", "vulcan-terminology");
        tag.setAttribute(
          "content",
          typeof content === "string" ? content : JSON.stringify(content),
        );
        document.head.appendChild(tag);
      }
      return import("@/constants/terminology");
    };

    afterEach(() => {
      removeTag();
      vi.resetModules();
    });

    it("behaves identically to the built-in defaults when the tag is absent", async () => {
      const mod = await importWithMetaTag(null);
      expect(mod.RULE_TERM).toEqual({ singular: "Rule", plural: "Rules", label: "Rule" });
      expect(mod.REQUIREMENT_TERM).toEqual({
        singular: "Requirement",
        plural: "Requirements",
        label: "Req",
      });
      expect(mod.ruleTerm("srg").plural).toBe("Requirements");
      expect(mod.navigatorLabels("srg").openRules).toBe("Open Requirements");
    });

    it("falls back to the defaults when the tag content is malformed JSON", async () => {
      const mod = await importWithMetaTag("{not json");
      expect(mod.ruleTerm("stig").singular).toBe("Rule");
      expect(mod.ruleTerm("srg").singular).toBe("Requirement");
    });

    it("flows an srg override through every accessor family and leaves stig at its default", async () => {
      const mod = await importWithMetaTag({
        stig: { singular: "Rule", plural: "Rules", label: "Rule" },
        srg: { singular: "Control", plural: "Controls", label: "Ctrl" },
      });

      // The exported constants themselves carry the override — this is how
      // importers that interpolate at module init (csvColumns, exportConfig,
      // ROLE_DESCRIPTIONS) pick it up without changes.
      expect(mod.REQUIREMENT_TERM).toEqual({
        singular: "Control",
        plural: "Controls",
        label: "Ctrl",
      });

      expect(mod.ruleTerm("srg").singular).toBe("Control");
      expect(mod.ruleTerm("stig").singular).toBe("Rule");
      expect(mod.panelLabels("srg").ruleHistory).toBe("Ctrl Changelog");
      expect(mod.sidebarTitles("srg").ruleHistory).toBe("Control Changelog");
      expect(mod.navigatorLabels("srg").openRules).toBe("Open Controls");
      expect(mod.messageLabels("srg").overallSection).toBe("Overall Control");
      expect(mod.reviewActionLabels("srg").lock.name).toBe("Lock Control");
      expect(mod.ruleCountLabel(2, "srg")).toBe("2 Controls");
      expect(mod.ruleCountLabel(1, "srg")).toBe("1 Control");
      expect(mod.selectedCountLabel(1, "srg")).toBe("1 control selected");
    });

    it("merges a partial override per part, keeping the other parts at their defaults", async () => {
      const mod = await importWithMetaTag({ srg: { singular: "Control" } });
      expect(mod.REQUIREMENT_TERM).toEqual({
        singular: "Control",
        plural: "Requirements",
        label: "Req",
      });
    });

    it("ignores blank and non-string override values", async () => {
      const mod = await importWithMetaTag({
        stig: { singular: "", plural: 7 },
        srg: { label: "   " },
      });
      expect(mod.RULE_TERM).toEqual({ singular: "Rule", plural: "Rules", label: "Rule" });
      expect(mod.REQUIREMENT_TERM.label).toBe("Req");
    });

    it("a family builder that ignores its term argument fails for BOTH kinds", async () => {
      // The falsifiable form of the deployment-rename pin: synthetic terms
      // on BOTH kinds, so a builder hardcoding either noun — or reading one
      // shared constant for both — cannot pass. Nothing here re-derives the
      // expectation from the constants under test.
      const mod = await importWithMetaTag({
        stig: { singular: "Widget", plural: "Widgets", label: "Wgt" },
        srg: { singular: "Gadget", plural: "Gadgets", label: "Gdt" },
      });
      expect(mod.navigatorLabels("stig").openRules).toBe("Open Widgets");
      expect(mod.navigatorLabels("srg").openRules).toBe("Open Gadgets");
      expect(mod.panelLabels("stig").ruleHistory).toBe("Wgt Changelog");
      expect(mod.panelLabels("srg").ruleHistory).toBe("Gdt Changelog");
      expect(mod.messageLabels("stig").saveTitle).toBe("Save Widget");
      expect(mod.messageLabels("srg").saveTitle).toBe("Save Gadget");
      expect(mod.reviewActionLabels("stig").lock.name).toBe("Lock Widget");
      expect(mod.reviewActionLabels("srg").lock.name).toBe("Lock Gadget");
    });

    it("the merged term exports are frozen", async () => {
      const mod = await importWithMetaTag(null);
      expect(Object.isFrozen(mod.RULE_TERM)).toBe(true);
      expect(Object.isFrozen(mod.REQUIREMENT_TERM)).toBe(true);
    });
  });
});
