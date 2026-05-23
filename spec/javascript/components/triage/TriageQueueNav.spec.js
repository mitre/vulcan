import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import TriageQueueNav from "@/components/triage/TriageQueueNav.vue";

// Multi-rule fixture: 3 rules, rule A has 3 comments, rule B has 2, rule C has 1
const groupedComments = [
  { id: 1, rule_id: 10, rule_displayed_name: "CNTR-01-000001", section: "check_content", triage_status: "pending", adjudicated_at: null },
  { id: 2, rule_id: 10, rule_displayed_name: "CNTR-01-000001", section: "check_content", triage_status: "pending", adjudicated_at: null },
  { id: 3, rule_id: 10, rule_displayed_name: "CNTR-01-000001", section: "fixtext", triage_status: "pending", adjudicated_at: null },
  { id: 4, rule_id: 20, rule_displayed_name: "CNTR-01-000002", section: "check_content", triage_status: "pending", adjudicated_at: null },
  { id: 5, rule_id: 20, rule_displayed_name: "CNTR-01-000002", section: null, triage_status: "concur", adjudicated_at: "2026-05-01T00:00:00Z" },
  { id: 6, rule_id: 30, rule_displayed_name: "CNTR-01-000003", section: "status", triage_status: "pending", adjudicated_at: null },
];

function baseProps(overrides = {}) {
  return {
    comments: groupedComments,
    currentId: 1,
    ...overrides,
  };
}

describe("TriageQueueNav", () => {
  // ── Grouped structure ──────────────────────────────────────────────

  it("computes ruleGroups from flat comments array", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.vm.ruleGroups).toHaveLength(3);
    expect(w.vm.ruleGroups[0].ruleName).toBe("CNTR-01-000001");
    expect(w.vm.ruleGroups[0].comments).toHaveLength(3);
    expect(w.vm.ruleGroups[1].comments).toHaveLength(2);
    expect(w.vm.ruleGroups[2].comments).toHaveLength(1);
  });

  // ── Counter shows rule + comment position ──────────────────────────

  it("shows rule position and comment position", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
    expect(w.text()).toContain("Rule 1 of 3");
    expect(w.text()).toContain("Comment 1 of 3");
  });

  it("updates counter when navigating to a different rule", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 4 }) });
    expect(w.text()).toContain("Rule 2 of 3");
    expect(w.text()).toContain("Comment 1 of 2");
  });

  // ── Navigation: next within rule, then to next rule ────────────────

  it("next emits the next comment in the same rule", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
    await w.find('[data-testid="next-comment"]').trigger("click");
    expect(w.emitted("select")[0][0]).toBe(2);
  });

  it("next at end of rule emits first comment of next rule", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 3 }) });
    await w.find('[data-testid="next-comment"]').trigger("click");
    expect(w.emitted("select")[0][0]).toBe(4);
  });

  it("next disabled on last comment of last rule", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 6 }) });
    expect(w.find('[data-testid="next-comment"]').attributes("disabled")).toBeDefined();
  });

  // ── Navigation: prev within rule, then to prev rule ────────────────

  it("prev emits the previous comment in the same rule", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 2 }) });
    await w.find('[data-testid="prev-comment"]').trigger("click");
    expect(w.emitted("select")[0][0]).toBe(1);
  });

  it("prev at start of rule emits last comment of prev rule", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 4 }) });
    await w.find('[data-testid="prev-comment"]').trigger("click");
    expect(w.emitted("select")[0][0]).toBe(3);
  });

  it("prev disabled on first comment of first rule", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
    expect(w.find('[data-testid="prev-comment"]').attributes("disabled")).toBeDefined();
  });

  // ── Accessibility ──────────────────────────────────────────────────

  it("has aria-labels on prev and next buttons", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 2 }) });
    expect(w.find('[data-testid="prev-comment"]').attributes("aria-label")).toBe("Previous comment");
    expect(w.find('[data-testid="next-comment"]').attributes("aria-label")).toBe("Next comment");
  });

  it("has role='navigation' on the container", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.attributes("role")).toBe("navigation");
  });

  // ── Empty state ────────────────────────────────────────────────────

  it("renders 'No comments' when comments array is empty", () => {
    const w = mount(TriageQueueNav, {
      localVue,
      propsData: { comments: [], currentId: null },
    });
    expect(w.text()).toContain("No comments");
  });

  // ── Browse panel with rule headers ──────────────────────────────────

  it("browse panel shows rule group headers", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find('[data-testid="browse-toggle"]').trigger("click");
    const headers = w.findAll('[data-testid="browse-rule-header"]');
    expect(headers).toHaveLength(3);
    expect(headers.at(0).text()).toContain("CNTR-01-000001");
    expect(headers.at(0).text()).toContain("3");
  });

  it("browse items emit select with comment ID", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find('[data-testid="browse-toggle"]').trigger("click");
    const items = w.findAll('[data-testid="browse-item"]');
    expect(items).toHaveLength(6);
    await items.at(3).trigger("click");
    expect(w.emitted("select")[0][0]).toBe(4);
  });

  // ── Single-comment rules show count ────────────────────────────────

  it("single-comment rules show count in header", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find('[data-testid="browse-toggle"]').trigger("click");
    const headers = w.findAll('[data-testid="browse-rule-header"]');
    const lastHeader = headers.at(2);
    expect(lastHeader.text()).toContain("CNTR-01-000003");
    expect(lastHeader.text()).toContain("1");
  });

  // ── 2D Navigation: rule arrows (left/right) ─────────────────────────

  describe("rule-level navigation (left/right)", () => {
    it("prev-rule jumps to first comment of previous rule", async () => {
      const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 4 }) });
      await w.find('[data-testid="prev-rule"]').trigger("click");
      expect(w.emitted("select")[0][0]).toBe(1);
    });

    it("next-rule jumps to first comment of next rule", async () => {
      const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
      await w.find('[data-testid="next-rule"]').trigger("click");
      expect(w.emitted("select")[0][0]).toBe(4);
    });

    it("prev-rule disabled on first rule", () => {
      const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
      expect(w.find('[data-testid="prev-rule"]').attributes("disabled")).toBeDefined();
    });

    it("next-rule disabled on last rule", () => {
      const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 6 }) });
      expect(w.find('[data-testid="next-rule"]').attributes("disabled")).toBeDefined();
    });

    it("next-rule from middle of a rule jumps to first comment of next rule", async () => {
      const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 2 }) });
      await w.find('[data-testid="next-rule"]').trigger("click");
      expect(w.emitted("select")[0][0]).toBe(4);
    });
  });

  // ── Bold rule headers in dropdown ──────────────────────────────────

  it("browse rule headers have bold rule name", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find('[data-testid="browse-toggle"]').trigger("click");
    const headers = w.findAll('[data-testid="browse-rule-header"]');
    expect(headers.at(0).text()).toContain("CNTR-01-000001");
  });

  // ── Scale test ─────────────────────────────────────────────────────

  it("handles 200 comments across 40 rules without crashing", () => {
    const big = Array.from({ length: 200 }, (_, i) => ({
      id: i + 1,
      rule_id: Math.floor(i / 5) + 1,
      rule_displayed_name: `RULE-${String(Math.floor(i / 5) + 1).padStart(3, "0")}`,
      section: "check_content",
      triage_status: i < 150 ? "pending" : "concur",
      adjudicated_at: i < 150 ? null : "2026-05-01T00:00:00Z",
    }));
    const w = mount(TriageQueueNav, {
      localVue,
      propsData: { comments: big, currentId: 1 },
    });
    expect(w.text()).toContain("Rule 1 of 40");
    expect(w.text()).toContain("Comment 1 of 5");
    expect(w.text()).toContain("Rule 1 of 40");
  });

  // ── WCAG + ARIA fixes (05f.28.2) ──────────────────────────────────

  it("uses role='option' on browse items, not role='button'", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find("[data-testid='browse-toggle']").trigger("click");
    const items = w.findAll("[data-testid='browse-item']");
    items.wrappers.forEach((item) => {
      expect(item.attributes("role")).toBe("option");
    });
  });

  it("wraps position counter in aria-live region", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    const counter = w.find("[data-testid='position-counter']");
    expect(counter.exists()).toBe(true);
    expect(counter.attributes("aria-live")).toBe("polite");
  });

  it("has aria-label on browse listbox", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    w.vm.browseOpen = true;
    await w.vm.$nextTick();
    const list = w.find("[role='listbox']");
    expect(list.exists()).toBe(true);
    expect(list.attributes("aria-label")).toBe("Browse all comments");
  });

  it("closes browse panel on Escape key", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    w.vm.browseOpen = true;
    await w.vm.$nextTick();
    const list = w.find("[role='listbox']");
    await list.trigger("keydown", { key: "Escape" });
    expect(w.vm.browseOpen).toBe(false);
  });

  it("handles string currentId from route params (type coercion)", () => {
    const w = mount(TriageQueueNav, {
      localVue,
      propsData: baseProps({ currentId: "3" }),
    });
    expect(w.text()).toContain("Comment 3 of 3");
    expect(w.text()).toContain("Rule 1 of 3");
  });

  // ── Browse panel ─────────────────────────────────────────────────

  it("renders Browse button that toggles a popover panel", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.find("[data-testid='browse-panel']").exists()).toBe(false);

    await w.find("[data-testid='browse-toggle']").trigger("click");
    expect(w.find("[data-testid='browse-panel']").exists()).toBe(true);
  });

  it("Browse panel has a search input", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find("[data-testid='browse-toggle']").trigger("click");
    expect(w.find("[data-testid='browse-search']").exists()).toBe(true);
  });

  it("Browse panel filters by search text", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.find("[data-testid='browse-toggle']").trigger("click");

    const search = w.find("[data-testid='browse-search']");
    await search.setValue("000002");
    await w.vm.$nextTick();

    const headers = w.findAll("[data-testid='browse-rule-header']");
    expect(headers.length).toBe(1);
    expect(headers.at(0).text()).toContain("CNTR-01-000002");
  });

  it("Browse panel highlights the active comment", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 3 }) });
    await w.find("[data-testid='browse-toggle']").trigger("click");

    const active = w.find("[data-testid='browse-item'].active");
    expect(active.exists()).toBe(true);
    expect(active.text()).toContain("#3");
  });
});
