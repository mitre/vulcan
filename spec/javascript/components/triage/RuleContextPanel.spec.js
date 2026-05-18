import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import RuleContextPanel from "@/components/triage/RuleContextPanel.vue";

const ruleContent = {
  rule_displayed_name: "CNTR-01-000001",
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

describe("RuleContextPanel", () => {
  // ── Heading ────────────────────────────────────────────────────────

  it("renders the rule display name as a heading", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    expect(w.text()).toContain("CNTR-01-000001");
  });

  it("renders the rule title below the heading", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    expect(w.text()).toContain("The container platform must limit privileges");
  });

  // ── Inline sections (single-line: severity, status) ────────────────

  it("renders severity as inline key:value (no accordion)", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    const section = w.find('[data-section="rule_severity"]');
    expect(section.exists()).toBe(true);
    expect(section.find(".section-header").exists()).toBe(false);
    expect(section.text()).toContain("Severity:");
    expect(section.text()).toContain("CAT II");
  });

  it("renders status as inline key:value", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    const section = w.find('[data-section="status"]');
    expect(section.exists()).toBe(true);
    expect(section.text()).toContain("Status:");
  });

  // ── Collapsible sections ───────────────────────────────────────────

  it("shows focused collapsible section body as visible", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    const section = w.find('[data-section="check_content"]');
    expect(section.exists()).toBe(true);
    expect(section.find(".section-body").isVisible()).toBe(true);
  });

  it("shows chevron-down icon on focused section", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    const header = w.find('[data-section="check_content"] .section-header');
    expect(header.find(".bi-chevron-down").exists()).toBe(true);
  });

  it("hides non-focused collapsible section bodies", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    const fixSection = w.find('[data-section="fixtext"]');
    expect(fixSection.exists()).toBe(true);
    expect(fixSection.find(".section-body").isVisible()).toBe(false);
  });

  it("shows chevron-right icon on collapsed sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    const fixHeader = w.find('[data-section="fixtext"] .section-header');
    expect(fixHeader.find(".bi-chevron-right").exists()).toBe(true);
  });

  // ── Manual toggle ──────────────────────────────────────────────────

  it("expands a collapsed section when its header is clicked", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    const fixHeader = w.find('[data-section="fixtext"] .section-header');
    await fixHeader.trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
  });

  // ── General comment (focusedSection = null) ────────────────────────

  it("expands all collapsible sections when focusedSection is null", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    const collapsible = w.findAll(".section-body");
    expect(collapsible.length).toBeGreaterThan(0);
    collapsible.wrappers.forEach((s) => {
      expect(s.isVisible()).toBe(true);
    });
  });

  // ── Component-scoped comment (ruleContent = null) ──────────────────

  it("renders 'Overall Component' banner when ruleContent is null", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent: null, ruleStatus: null, focusedSection: null },
    });
    expect(w.text()).toContain("Overall Component");
    expect(w.findAll("[data-section]").length).toBe(0);
  });

  // ── Section labels ─────────────────────────────────────────────────

  it("uses friendly labels for sections", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    expect(w.text()).toContain("Check");
    expect(w.text()).toContain("Fix");
    expect(w.text()).toContain("Vulnerability Discussion");
  });

  // ── Status-driven field visibility ─────────────────────────────────

  it("uses STATUS_FIELD_CONFIG to determine visible fields per status", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: null },
    });
    expect(w.find('[data-section="fixtext"]').exists()).toBe(true);
    expect(w.find('[data-section="check_content"]').exists()).toBe(true);
    expect(w.find('[data-section="vuln_discussion"]').exists()).toBe(true);
    expect(w.find('[data-section="vendor_comments"]').exists()).toBe(true);
  });

  it("hides check_content for 'Not Applicable' status", () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Not Applicable", focusedSection: null },
    });
    expect(w.find('[data-section="check_content"]').exists()).toBe(false);
  });

  it("shows status_justification for 'Applicable - Does Not Meet' status", () => {
    const contentWithJustification = {
      ...ruleContent,
      status: "Applicable - Does Not Meet",
      status_justification: "This system does not support this feature",
    };
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: {
        ruleContent: contentWithJustification,
        ruleStatus: "Applicable - Does Not Meet",
        focusedSection: null,
      },
    });
    expect(w.find('[data-section="status_justification"]').exists()).toBe(true);
  });

  // ── focusedSection watcher resets manual toggles ───────────────────

  it("resets manual toggles when focusedSection prop changes", async () => {
    const w = mount(RuleContextPanel, {
      localVue,
      propsData: { ruleContent, ruleStatus: "Applicable - Configurable", focusedSection: "check_content" },
    });
    await w.find('[data-section="fixtext"] .section-header').trigger("click");
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);

    await w.setProps({ focusedSection: "fixtext" });
    expect(w.find('[data-section="fixtext"] .section-body').isVisible()).toBe(true);
    expect(w.find('[data-section="check_content"] .section-body').isVisible()).toBe(false);
  });
});
