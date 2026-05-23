import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleContextPanel from "@/components/triage/RuleContextPanel.vue";

const ruleContent = {
  title: "The container platform must limit privileges",
  rule_severity: "CAT II",
  status: "Applicable - Configurable",
  fixtext: "Configure the container platform to restrict access to privileged operations",
  check_content:
    "Verify that the container runtime enforces privilege restrictions on all workloads",
  vuln_discussion:
    "Without proper privilege restriction, containers could escalate to host-level access",
  vendor_comments: "Vendor acknowledges this requirement",
  status_justification: null,
  artifact_description: null,
};

function props(overrides = {}) {
  return {
    ruleContent,
    ruleDisplayedName: "CNTR-01-000001",
    ruleStatus: "Applicable - Configurable",
    focusedSection: null,
    ...overrides,
  };
}

describe("RuleContextPanel", () => {
  // ── Heading from ruleDisplayedName prop (NOT ruleContent) ──────────

  it("renders the heading from ruleDisplayedName prop", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.text()).toContain("CNTR-01-000001");
  });

  it("renders the rule title below the heading", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.text()).toContain("The container platform must limit privileges");
  });

  it("does NOT read rule_displayed_name from ruleContent", () => {
    const contentWithName = { ...ruleContent, rule_displayed_name: "WRONG-NAME" };
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ ruleContent: contentWithName, ruleDisplayedName: "RIGHT-NAME" }),
    });
    expect(w.text()).toContain("RIGHT-NAME");
    expect(w.text()).not.toContain("WRONG-NAME");
  });

  // ── Inline sections (severity, status) ─────────────────────────────

  it("renders severity as inline key:value", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const section = w.find('[data-section="rule_severity"]');
    expect(section.exists()).toBe(true);
    expect(section.find(".section-header").exists()).toBe(false);
    expect(section.text()).toContain("Severity:");
    expect(section.text()).toContain("CAT II");
  });

  it("renders status as inline key:value", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const section = w.find('[data-section="status"]');
    expect(section.exists()).toBe(true);
    expect(section.text()).toContain("Status:");
    expect(section.text()).toContain("Applicable - Configurable");
  });

  // ── Collapsible sections (fisheye) ─────────────────────────────────

  it("expands the focused section body", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    const section = w.find('[data-section="check_content"]');
    expect(section.exists()).toBe(true);
    expect(section.find(".section-body").isVisible()).toBe(true);
    expect(section.text()).toContain("Verify that the container runtime");
  });

  it("shows chevron-down on focused section", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    expect(w.find('[data-section="check_content"] .section-header .bi-chevron-down').exists()).toBe(
      true,
    );
  });

  it("collapses non-focused sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.exists()).toBe(true);
    expect(fixSection.find(".section-body").isVisible()).toBe(false);
  });

  it("shows chevron-right on collapsed sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    expect(w.find('[data-section="fixtext"] .section-header .bi-chevron-right').exists()).toBe(true);
  });

  // ── Manual toggle ──────────────────────────────────────────────────

  it("expands collapsed section on click", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    await w.find('[data-section="fixtext"] .section-header').trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
  });

  // ── General comment (focusedSection = null) ────────────────────────

  it("expands all collapsible sections when focusedSection is null", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const bodies = w.findAll(".section-body");
    expect(bodies.length).toBeGreaterThan(0);
    bodies.wrappers.forEach((b) => expect(b.isVisible()).toBe(true));
  });

  // ── Null ruleContent (component-scoped comment) ────────────────────

  it("renders 'Overall Component' banner when ruleContent is null", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ ruleContent: null, ruleDisplayedName: null }),
    });
    expect(w.text()).toContain("Overall Component");
    expect(w.findAll("[data-section]").length).toBe(0);
  });

  // ── Section labels ─────────────────────────────────────────────────

  it("uses friendly labels for sections", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.text()).toContain("Check");
    expect(w.text()).toContain("Fix");
    expect(w.text()).toContain("Vulnerability Discussion");
  });

  // ── STATUS_FIELD_CONFIG drives visibility ──────────────────────────

  it("shows check_content for Applicable - Configurable", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.find('[data-section="check_content"]').exists()).toBe(true);
  });

  it("hides check_content for Not Applicable status", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ ruleStatus: "Not Applicable" }),
    });
    expect(w.find('[data-section="check_content"]').exists()).toBe(false);
  });

  it("shows status_justification for Applicable - Does Not Meet", () => {
    const contentWithJustification = {
      ...ruleContent,
      status_justification: "This system does not support this feature",
    };
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({
        ruleContent: contentWithJustification,
        ruleStatus: "Applicable - Does Not Meet",
      }),
    });
    expect(w.find('[data-section="status_justification"]').exists()).toBe(true);
  });

  // ── Unknown ruleStatus falls back gracefully ───────────────────────

  it("falls back to showing all non-null fields for unknown ruleStatus", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ ruleStatus: "Some Unknown Status" }),
    });
    expect(w.findAll("[data-section]").length).toBeGreaterThan(0);
    expect(w.text()).toContain("Vulnerability Discussion");
  });

  // ── focusedSection watcher resets toggles ───────────────────────────

  it("resets manual toggles when focusedSection changes", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    await w.find('[data-section="fixtext"] .section-header').trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);

    await w.setProps({ focusedSection: "fixtext" });
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
    expect(w.find('[data-section="check_content"] .section-body').isVisible()).toBe(false);
  });

  // ── contextMode: "commented" filters to commented sections only ─────

  it("in 'commented' mode shows only sections in commentedSections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({
        contextMode: "commented",
        commentedSections: new Set(["check_content", "fixtext"]),
      }),
    });
    expect(w.find('[data-section="check_content"]').exists()).toBe(true);
    expect(w.find('[data-section="fixtext"]').exists()).toBe(true);
    expect(w.find('[data-section="vuln_discussion"]').exists()).toBe(false);
    expect(w.find('[data-section="vendor_comments"]').exists()).toBe(false);
  });

  it("in 'all' mode shows all fields regardless of commentedSections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({
        contextMode: "all",
        commentedSections: new Set(["check_content"]),
      }),
    });
    expect(w.find('[data-section="check_content"]').exists()).toBe(true);
    expect(w.find('[data-section="fixtext"]').exists()).toBe(true);
    expect(w.find('[data-section="vuln_discussion"]').exists()).toBe(true);
  });

  // ── Labels come from FIELD_LABELS registry (Gate 5: DRY) ──────────

  it("imports labels from ruleFieldConfig, not a local dict", async () => {
    const { FIELD_LABELS } = await import("@/composables/ruleFieldConfig");
    expect(FIELD_LABELS).toBeDefined();
    expect(FIELD_LABELS.check_content).toBe("Check");
    expect(FIELD_LABELS.vuln_discussion).toBe("Vulnerability Discussion");
    expect(FIELD_LABELS.rule_severity).toBe("Severity");
  });

  // ── Section comment count badges (agw.11) ──────────────────────────

  describe("section comment count badges", () => {
    const sectionCounts = { check_content: 3, fixtext: 1 };

    it("shows badge with count 3 on check_content section header", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ sectionCommentCounts: sectionCounts }),
      });
      const badge = w.find('[data-section="check_content"] .comment-count-badge');
      expect(badge.exists()).toBe(true);
      expect(badge.text()).toBe("3");
    });

    it("shows badge with count 1 on fixtext section", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ sectionCommentCounts: sectionCounts }),
      });
      const badge = w.find('[data-section="fixtext"] .comment-count-badge');
      expect(badge.exists()).toBe(true);
      expect(badge.text()).toBe("1");
    });

    it("shows no badge when section has 0 comments", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ sectionCommentCounts: sectionCounts }),
      });
      const badge = w.find('[data-section="vuln_discussion"] .comment-count-badge');
      expect(badge.exists()).toBe(false);
    });

    it("shows no badges when sectionCommentCounts is empty", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ sectionCommentCounts: {} }),
      });
      expect(w.findAll(".comment-count-badge").length).toBe(0);
    });
  });

  // ── Fix 2: No inline comments in triage panel ──────────────────────
  // REQUIREMENT: Sidebar handles comment navigation — inline comment
  // stubs in the rule content panel are a duplicate affordance that
  // violates Nielsen's consistency heuristic.

  it("does NOT render inline comment stubs under section headers", () => {
    const sectionComments = [
      { id: 1, section: "check_content", author_name: "Viewer", comment: "First", triage_status: "pending" },
      { id: 2, section: "check_content", author_name: "Reviewer", comment: "Second", triage_status: "concur" },
    ];
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({
        focusedSection: "check_content",
        sectionComments,
        activeCommentId: 1,
        sectionCommentCounts: { check_content: 2 },
      }),
    });
    expect(w.findAll(".related-comment").length).toBe(0);
    expect(w.findAll(".related-comments-list").length).toBe(0);
  });

  it("still shows section comment count badges after removing inline comments", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ sectionCommentCounts: { check_content: 3, fixtext: 1 } }),
    });
    const badge = w.find('[data-section="check_content"] .comment-count-badge');
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("3");
  });

  // ── Fix 4: Advanced fields toggle (default collapsed) ──────────────
  // REQUIREMENT: Advanced fields (status_justification, version,
  // rule_weight, etc.) should be hidden by default in triage mode.
  // Triagers can expand them but shouldn't see the full kitchen sink.

  describe("advanced fields toggle", () => {
    it("hides advanced fields by default", () => {
      const contentWithAdvanced = {
        ...ruleContent,
        status_justification: "Because reasons",
        version: "003.001",
        rule_weight: "10.0",
      };
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ ruleContent: contentWithAdvanced }),
      });
      expect(w.find('[data-section="status_justification"]').exists()).toBe(false);
      expect(w.find('[data-section="version"]').exists()).toBe(false);
    });

    it("shows advanced fields when toggle is enabled", async () => {
      const contentWithAdvanced = {
        ...ruleContent,
        status_justification: "Because reasons",
        version: "003.001",
      };
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ ruleContent: contentWithAdvanced }),
      });
      w.vm.showAdvanced = true;
      await w.vm.$nextTick();
      expect(w.find('[data-section="status_justification"]').exists()).toBe(true);
      expect(w.find('[data-section="version"]').exists()).toBe(true);
    });

    it("renders an Advanced Fields toggle switch", () => {
      const w = mount(RuleContextPanel, { localVue, propsData: props() });
      const toggle = w.find("[data-testid='advanced-fields-toggle']");
      expect(toggle.exists()).toBe(true);
    });
  });

  // ── Fix 5: Focused section background highlight ────────────────────

  it("applies focus background tint to the focused section body", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    const body = w.find('[data-section="check_content"] .section-body');
    expect(body.classes()).toContain("section-body--focused");
  });

  it("does NOT apply focus tint to non-focused sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ focusedSection: "check_content" }),
    });
    const body = w.find('[data-section="fixtext"] .section-body');
    expect(body.classes()).not.toContain("section-body--focused");
  });

  // ── 05f.28.1: unknown fields must sort AFTER known fields ──────

  it("indexOf sort uses ternary not nullish coalescing for -1", async () => {
    const { FIELD_DISPLAY_ORDER } = await import("@/composables/ruleFieldConfig");
    const idxMiss = FIELD_DISPLAY_ORDER.indexOf("nonexistent_field");
    expect(idxMiss).toBe(-1);
    const sortVal = idxMiss === -1 ? 999 : idxMiss;
    expect(sortVal).toBe(999);
    const buggyVal = idxMiss ?? 999;
    expect(buggyVal).toBe(-1);
  });

  // ── 05f.25: visibleFields sorted by FIELD_DISPLAY_ORDER ─────────
  // REQUIREMENT: Triage panel must show fields in the same order as
  // the editor (RuleForm.vue). Previously concatenated config arrays
  // in wrong order (fix before vuln_discussion).

  it("renders vuln_discussion before check_content (FIELD_DISPLAY_ORDER)", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const sections = w.findAll("[data-section]").wrappers.map((s) => s.attributes("data-section"));
    const vulnIdx = sections.indexOf("vuln_discussion");
    const checkIdx = sections.indexOf("check_content");
    expect(vulnIdx).toBeGreaterThan(-1);
    expect(checkIdx).toBeGreaterThan(-1);
    expect(vulnIdx).toBeLessThan(checkIdx);
  });

  it("renders check_content before fixtext (FIELD_DISPLAY_ORDER)", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const sections = w.findAll("[data-section]").wrappers.map((s) => s.attributes("data-section"));
    const checkIdx = sections.indexOf("check_content");
    const fixIdx = sections.indexOf("fixtext");
    expect(checkIdx).toBeGreaterThan(-1);
    expect(fixIdx).toBeGreaterThan(-1);
    expect(checkIdx).toBeLessThan(fixIdx);
  });

  it("renders fixtext before vendor_comments (FIELD_DISPLAY_ORDER)", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const sections = w.findAll("[data-section]").wrappers.map((s) => s.attributes("data-section"));
    const fixIdx = sections.indexOf("fixtext");
    const vendorIdx = sections.indexOf("vendor_comments");
    expect(fixIdx).toBeGreaterThan(-1);
    expect(vendorIdx).toBeGreaterThan(-1);
    expect(fixIdx).toBeLessThan(vendorIdx);
  });

  // ── Notification badge on section comment count ─────────────────────

  it("renders comment count as a superscript badge, not inline text", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: props({ sectionCommentCounts: { check_content: 3 } }),
    });
    const badge = w.find('[data-section="check_content"] .comment-count-badge');
    expect(badge.exists()).toBe(true);
    expect(badge.text()).toBe("3");
  });

  // ── Visual separator between header and content ───────────────────

  it("renders a separator between header controls and rule description", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.find(".rule-context-header").exists()).toBe(true);
    expect(w.find(".rule-context-divider").exists()).toBe(true);
  });

  // ── Header: rule name row + controls row ────────────────────────────

  it("renders rule name separate from controls toolbar", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    const nameRow = w.find(".rule-context-header");
    const toolbar = w.find("[data-testid='context-toolbar']");
    expect(nameRow.text()).toContain("CNTR-01-000001");
    expect(nameRow.find("[data-testid='context-mode-toggle']").exists()).toBe(false);
    expect(toolbar.find("[data-testid='context-mode-toggle']").exists()).toBe(true);
    expect(toolbar.find("[data-testid='advanced-fields-toggle']").exists()).toBe(true);
    expect(toolbar.find("[data-testid='toggle-sections']").exists()).toBe(true);
  });

  // ── Expand/collapse toggle (single button) ─────────────────────────

  it("toggles all sections expanded/collapsed with one button", async () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
    await w.find("[data-testid='toggle-sections']").trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(false);
    await w.find("[data-testid='toggle-sections']").trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
  });

  // ── Fix 6: Toggle label is "Focus Section" not "All Fields" ───────

  it("labels the context mode toggle as 'Focus Section'", () => {
    const w = mount(RuleContextPanel, { localVue, propsData: props() });
    expect(w.text()).toContain("Focus Section");
    expect(w.text()).not.toContain("All Fields");
  });

  // ── Locked status ──────────────────────────────────────────────────

  describe("locked status indicator", () => {
    it("shows lock icon when ruleContent.locked is true", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ ruleContent: { ...ruleContent, locked: true } }),
      });
      expect(w.find("[data-testid='locked-indicator']").exists()).toBe(true);
      expect(w.text()).toContain("Locked");
    });

    it("does not show lock icon when ruleContent.locked is false", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props({ ruleContent: { ...ruleContent, locked: false } }),
      });
      expect(w.find("[data-testid='locked-indicator']").exists()).toBe(false);
    });

    it("does not show lock icon when locked is not present", () => {
      const w = mount(RuleContextPanel, {
        localVue,
        propsData: props(),
      });
      expect(w.find("[data-testid='locked-indicator']").exists()).toBe(false);
    });
  });
});
