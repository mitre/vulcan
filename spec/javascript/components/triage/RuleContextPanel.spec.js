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
});
