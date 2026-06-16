import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentProgressBar from "@/components/triage/CommentProgressBar.vue";

const statusCounts = {
  pending: 16,
  concur: 3,
  non_concur: 1,
  informational: 1,
  withdrawn: 2,
};

function baseProps(overrides = {}) {
  return { statusCounts, ...overrides };
}

describe("CommentProgressBar", () => {
  // ── Summary pills (label + count badges) ──────────────────────────

  it("renders an All pill plus one pill per non-zero status", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pills = w.findAll("[data-testid='status-pill']");
    expect(pills.length).toBe(6);
    expect(pills.at(0).text()).toContain("All: 23");
  });

  it("does not render pills for zero-count statuses (All pill still shows)", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: { pending: 5, concur: 0, non_concur: 3 } }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    expect(pills.length).toBe(3);
  });

  it("each pill shows the friendly label text from triageVocabulary", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pills = w.findAll("[data-testid='status-pill']");
    const texts = pills.wrappers.map((p) => p.text());
    expect(texts).toContain("Accepted: 3");
    expect(texts).toContain("Declined: 1");
    expect(texts).toContain("Informational: 1");
    expect(texts).toContain("Withdrawn: 2");
    expect(texts).toContain("Pending: 16");
  });

  it("applies color class per status on each pill", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pills = w.findAll("[data-testid='status-pill']");
    const pendingPill = pills.wrappers.find((p) => p.text().includes("Pending"));
    expect(pendingPill.classes()).toContain("progress-pill--pending");
    const accChangesPill = pills.wrappers.find((p) => p.text().includes("Accepted with Changes"));
    if (accChangesPill) {
      expect(accChangesPill.classes()).toContain("progress-pill--concur_with_comment");
    }
  });

  it("concur_with_comment pill has a distinct class from concur (not both green)", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: { concur: 2, concur_with_comment: 3 } }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    const classes = pills.wrappers.map((p) =>
      p.classes().find((c) => c.startsWith("progress-pill--")),
    );
    expect(classes).toContain("progress-pill--concur");
    expect(classes).toContain("progress-pill--concur_with_comment");
    expect(classes[0]).not.toBe(classes[1]);
  });

  // ── Pill order: resolved first, pending last (progress framing) ───

  it("orders pills as All | Pending | separator | resolved statuses", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({
        statusCounts: { withdrawn: 5, pending: 10, concur: 3 },
      }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    const labels = pills.wrappers.map((p) => p.text());
    expect(labels[0]).toContain("All: 18");
    expect(labels[1]).toContain("Pending: 10");
    expect(labels[2]).toContain("Accepted: 3");
    expect(labels[3]).toContain("Withdrawn: 5");
  });

  // ── Thin stacked bar ──────────────────────────────────────────────

  it("renders a bar segment for each non-zero status", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const segments = w.findAll("[data-testid='progress-segment']");
    expect(segments.length).toBe(5);
  });

  it("sets segment widths roughly proportional to count / total", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const segments = w.findAll("[data-testid='progress-segment']");
    const pendingSegment = segments.wrappers.find((s) =>
      s.classes().includes("progress-segment--pending"),
    );
    const pendingWidth = parseFloat(pendingSegment.element.style.width);
    expect(pendingWidth).toBeGreaterThan(50);
    expect(pendingWidth).toBeLessThan(80);
  });

  it("enforces a minimum segment width so thin slivers are visible", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: { pending: 200, concur: 1 } }),
    });
    const segments = w.findAll("[data-testid='progress-segment']");
    const thinSegment = segments.at(0);
    const rawWidth = (1 / 201) * 100;
    const renderedWidth = parseFloat(thinSegment.element.style.width);
    expect(renderedWidth).toBeGreaterThanOrEqual(2);
    expect(renderedWidth).toBeGreaterThan(rawWidth);
  });

  // ── Summary line (progress-framed, left-aligned with bar) ─────────

  it("displays progress-framed summary: resolved count and percentage", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const summary = w.find("[data-testid='progress-summary']");
    expect(summary.text()).toContain("7 of 23 resolved");
    expect(summary.text()).toMatch(/30(.4)?%/);
  });

  it("summary is left-aligned below the bar, not stranded right", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const summary = w.find("[data-testid='progress-summary']");
    expect(summary.classes()).not.toContain("ml-2");
  });

  // ── Edge cases ────────────────────────────────────────────────────

  it("renders nothing when statusCounts is empty", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: {} }),
    });
    expect(w.find("[data-testid='progress-bar']").exists()).toBe(false);
    expect(w.findAll("[data-testid='status-pill']").length).toBe(0);
  });

  it("handles a single status gracefully (All + Pending pills)", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: { pending: 10 } }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    expect(pills.length).toBe(2);
    expect(pills.at(0).text()).toContain("All: 10");
    expect(pills.at(1).text()).toContain("Pending: 10");
    const summary = w.find("[data-testid='progress-summary']");
    expect(summary.text()).toContain("0 of 10 resolved");
  });

  // ── Click-to-filter ────────────────────────────────────────────────

  it("emits 'filter' with the status key when a pill is clicked", async () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pills = w.findAll("[data-testid='status-pill']");
    const declinedPill = pills.wrappers.find((p) => p.text().includes("Declined"));
    await declinedPill.trigger("click");
    expect(w.emitted("filter")).toHaveLength(1);
    expect(w.emitted("filter")[0][0]).toBe("non_concur");
  });

  it("emits 'filter' with 'all' when clicking the already-active pill (toggle off)", async () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ activeFilter: "non_concur" }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    const declinedPill = pills.wrappers.find((p) => p.text().includes("Declined"));
    await declinedPill.trigger("click");
    expect(w.emitted("filter")[0][0]).toBe("all");
  });

  it("adds active indicator class to pill matching activeFilter prop", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ activeFilter: "concur" }),
    });
    const pills = w.findAll("[data-testid='status-pill']");
    const acceptedPill = pills.wrappers.find((p) => p.text().includes("Accepted: 3"));
    expect(acceptedPill.classes()).toContain("progress-pill--active");
  });

  it("pills have cursor:pointer style", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pill = w.find("[data-testid='status-pill']");
    expect(pill.classes()).toContain("progress-pill");
  });

  // ── Edge cases ────────────────────────────────────────────────────

  it("shows 100% when all comments are resolved", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: baseProps({ statusCounts: { concur: 5, non_concur: 2 } }),
    });
    const summary = w.find("[data-testid='progress-summary']");
    expect(summary.text()).toContain("7 of 7 resolved");
    expect(summary.text()).toContain("100%");
  });

  // Defensive: segment widths must sum to 100% even if statusCounts contains
  // a key that doesn't map to a bucket — otherwise the unfilled remainder
  // exposes the track background and reads as a mystery dark-gray segment.
  it("normalizes segment widths to 100% even with unrecognized status keys", () => {
    const w = mount(CommentProgressBar, {
      localVue,
      propsData: {
        statusCounts: {
          pending: 87,
          concur: 1,
          concur_with_comment: 19,
          duplicate: 4,
          informational: 1,
          _ghost: 1,
        },
      },
    });
    const segments = w.findAll("[data-testid='progress-segment']");
    const sum = segments.wrappers.reduce((s, seg) => s + parseFloat(seg.element.style.width), 0);
    expect(sum).toBeCloseTo(100, 0);
  });

  it("preserves the pending data-triage marker (drives the legibility stripe)", () => {
    const w = mount(CommentProgressBar, { localVue, propsData: baseProps() });
    const pending = w
      .findAll("[data-testid='progress-segment']")
      .wrappers.find((s) => s.attributes("data-triage") === "pending");
    expect(pending).toBeTruthy();
  });
});
