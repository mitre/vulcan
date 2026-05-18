import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import TriageQueueNav from "@/components/triage/TriageQueueNav.vue";

function makeComments(count, pendingCount = 0) {
  return Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    rule_displayed_name: `RULE-${String(i + 1).padStart(3, "0")}`,
    triage_status: i < pendingCount ? "pending" : "concur",
    adjudicated_at: i < pendingCount ? null : "2026-05-01T00:00:00Z",
    section: "check_content",
  }));
}

const threeComments = makeComments(3, 2);

function baseProps(overrides = {}) {
  return {
    comments: threeComments,
    currentId: threeComments[0].id,
    ...overrides,
  };
}

describe("TriageQueueNav", () => {
  // ── Position counter ───────────────────────────────────────────────

  it("renders position counter 'N of Total'", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.text()).toContain("1 of 3");
  });

  it("updates position when currentId changes", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    await w.setProps({ currentId: threeComments[1].id });
    expect(w.text()).toContain("2 of 3");
  });

  // ── Pending count ──────────────────────────────────────────────────

  it("renders pending count", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.text()).toContain("2 pending");
  });

  it("renders '0 pending' when all are triaged", () => {
    const allTriaged = makeComments(3, 0);
    const w = mount(TriageQueueNav, {
      localVue,
      propsData: { comments: allTriaged, currentId: allTriaged[0].id },
    });
    expect(w.text()).toContain("0 pending");
  });

  // ── Prev/Next buttons ─────────────────────────────────────────────

  it("prev button is disabled on the first item", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
    const prev = w.find('[data-testid="prev-comment"]');
    expect(prev.attributes("disabled")).toBeTruthy();
  });

  it("next button is disabled on the last item", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 3 }) });
    const next = w.find('[data-testid="next-comment"]');
    expect(next.attributes("disabled")).toBeTruthy();
  });

  it("prev button emits select with previous comment ID", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 2 }) });
    await w.find('[data-testid="prev-comment"]').trigger("click");
    expect(w.emitted("select")).toBeTruthy();
    expect(w.emitted("select")[0][0]).toBe(1);
  });

  it("next button emits select with next comment ID", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 1 }) });
    await w.find('[data-testid="next-comment"]').trigger("click");
    expect(w.emitted("select")).toBeTruthy();
    expect(w.emitted("select")[0][0]).toBe(2);
  });

  // ── Accessibility ──────────────────────────────────────────────────

  it("has aria-label on prev and next buttons", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps({ currentId: 2 }) });
    expect(w.find('[data-testid="prev-comment"]').attributes("aria-label")).toBe(
      "Previous comment",
    );
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

  // ── Dropdown ───────────────────────────────────────────────────────

  it("renders a dropdown toggle for jump-to navigation", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    expect(w.find('[data-testid="queue-dropdown"]').exists()).toBe(true);
  });

  it("dropdown items show #id (not array position) for clarity", () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    const items = w.findAll('[data-testid="queue-dropdown-item"]');
    expect(items.at(0).text()).toContain("#1");
    expect(items.at(2).text()).toContain("#3");
  });

  it("dropdown items emit select with the chosen comment ID", async () => {
    const w = mount(TriageQueueNav, { localVue, propsData: baseProps() });
    const items = w.findAll('[data-testid="queue-dropdown-item"]');
    expect(items.length).toBe(3);
    await items.at(2).trigger("click");
    expect(w.emitted("select")).toBeTruthy();
    expect(w.emitted("select")[0][0]).toBe(3);
  });

  // ── Scale test ─────────────────────────────────────────────────────

  it("handles 200 items without crashing (renders counter correctly)", () => {
    const big = makeComments(200, 150);
    const w = mount(TriageQueueNav, {
      localVue,
      propsData: { comments: big, currentId: big[49].id },
    });
    expect(w.text()).toContain("50 of 200");
    expect(w.text()).toContain("150 pending");
  });
});
