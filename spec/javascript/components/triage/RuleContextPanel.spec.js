import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleContextPanel from "@/components/triage/RuleContextPanel.vue";

const ruleContent = {
  rule_displayed_name: "CNTR-01-000001",
  rule_title: "The container platform must limit privileges",
  rule_severity: "CAT II",
  rule_status: "Applicable - Configurable",
  rule_fixtext: "Configure the container platform to restrict access to privileged operations",
  rule_check_content:
    "Verify that the container runtime enforces privilege restrictions on all workloads",
  rule_vuln_discussion:
    "Without proper privilege restriction, containers could escalate to host-level access",
};

describe("RuleContextPanel", () => {
  // ── Heading ────────────────────────────────────────────────────────

  it("renders the rule display name as a heading", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    expect(w.text()).toContain("CNTR-01-000001");
  });

  it("renders the rule title below the heading", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    expect(w.text()).toContain("The container platform must limit privileges");
  });

  // ── Inline sections (single-line: title, severity, status) ─────────

  it("renders title, severity, status as inline key:value pairs (no accordion)", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    const titleSection = w.find('[data-section="title"]');
    expect(titleSection.exists()).toBe(true);
    expect(titleSection.find(".section-header").exists()).toBe(false);
    expect(titleSection.find(".section-body").exists()).toBe(false);
    expect(titleSection.text()).toContain("Title:");
    expect(titleSection.text()).toContain("The container platform must limit privileges");
  });

  it("renders severity inline", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    const section = w.find('[data-section="severity"]');
    expect(section.exists()).toBe(true);
    expect(section.text()).toContain("Severity:");
    expect(section.text()).toContain("CAT II");
  });

  it("renders status inline", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    const section = w.find('[data-section="status"]');
    expect(section.exists()).toBe(true);
    expect(section.text()).toContain("Status:");
    expect(section.text()).toContain("Applicable - Configurable");
  });

  // ── Collapsible sections (multi-line: fix, check, vuln_discussion) ─

  it("shows focused collapsible section body as visible", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const section = w.find('[data-section="check_content"]');
    expect(section.exists()).toBe(true);
    expect(section.find(".section-body").isVisible()).toBe(true);
    expect(section.text()).toContain("Verify that the container runtime");
  });

  it("shows chevron-down icon on focused section", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const header = w.find('[data-section="check_content"] .section-header');
    expect(header.find(".bi-chevron-down").exists()).toBe(true);
  });

  it("hides non-focused collapsible section bodies", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.exists()).toBe(true);
    expect(fixSection.find(".section-body").isVisible()).toBe(false);
  });

  it("shows a one-line preview on collapsed sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.find(".section-preview").exists()).toBe(true);
  });

  it("shows chevron-right icon on collapsed sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixHeader = w.find('[data-section="fixtext"] .section-header');
    expect(fixHeader.find(".bi-chevron-right").exists()).toBe(true);
  });

  // ── Manual toggle ──────────────────────────────────────────────────

  it("expands a collapsed section when its header is clicked", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const fixHeader = w.find('[data-section="fixtext"] .section-header');
    await fixHeader.trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
  });

  it("collapses an expanded section when its header is clicked", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    const checkHeader = w.find('[data-section="check_content"] .section-header');
    await checkHeader.trigger("click");
    expect(w.find('[data-section="check_content"] .section-body').isVisible()).toBe(false);
  });

  // ── General comment (focusedSection = null) ────────────────────────

  it("expands all collapsible sections when focusedSection is null", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    const collapsible = w.findAll(".section-body");
    expect(collapsible.length).toBe(3);
    collapsible.wrappers.forEach((s) => {
      expect(s.isVisible()).toBe(true);
    });
  });

  // ── Component-scoped comment (ruleContent = null) ──────────────────

  it("renders 'Overall Component' banner when ruleContent is null", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent: null, focusedSection: null },
    });
    expect(w.text()).toContain("Overall Component");
    expect(w.findAll("[data-section]").length).toBe(0);
  });

  // ── Section labels from triageVocabulary ───────────────────────────

  it("uses SECTION_LABELS from triageVocabulary.js for display labels", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: null },
    });
    expect(w.text()).toContain("Check");
    expect(w.text()).toContain("Fix");
    expect(w.text()).toContain("Vulnerability Discussion");
  });

  // ── Only renders sections with content ─────────────────────────────

  it("does not render sections that have no content in ruleContent", () => {
    const sparseContent = {
      rule_displayed_name: "TEST-000001",
      rule_title: "Test rule",
      rule_severity: null,
      rule_status: null,
      rule_fixtext: "Fix text here",
      rule_check_content: null,
      rule_vuln_discussion: null,
    };
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent: sparseContent, focusedSection: null },
    });
    expect(w.find('[data-section="fixtext"]').exists()).toBe(true);
    expect(w.find('[data-section="check_content"]').exists()).toBe(false);
    expect(w.find('[data-section="severity"]').exists()).toBe(false);
  });

  // ── focusedSection watcher resets manual toggles ───────────────────

  it("resets manual toggles when focusedSection prop changes", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, focusedSection: "check_content" },
    });
    await w.find('[data-section="fixtext"] .section-header').trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);

    await w.setProps({ focusedSection: "fixtext" });
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
    expect(w.find('[data-section="check_content"] .section-body').isVisible()).toBe(false);
  });
});
