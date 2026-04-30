import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentPeriodBanner from "@/components/components/CommentPeriodBanner.vue";

/**
 * REQUIREMENTS (PR #717 — Task 21):
 *
 * The CommentPeriodBanner sits at the top of the Component page so EVERY
 * page visitor — commenter, triager, admin — sees the comment-window
 * lifecycle state immediately. Plain English over jargon.
 *
 * 1. Hidden entirely when phase = "draft" (no public window yet, no need
 *    to broadcast anything).
 * 2. When phase = "open", surfaces "Open for comment" + "N days remaining"
 *    + the pending-triage count if provided. The variant is informational
 *    (info / blue) so it announces, not alarms.
 * 3. When phase = "adjudication", surfaces the "Adjudication" label so
 *    triagers know the window is closed but disposition is pending. The
 *    variant is warning to draw attention to the open work.
 * 4. role="status" makes phase-change announcements audible to assistive
 *    technologies (WCAG 4.1.3).
 * 5. The "Open Comments panel" link emits an event the parent uses to open
 *    the existing slideover (does NOT navigate / reload).
 */
describe("CommentPeriodBanner", () => {
  it("renders nothing when phase is draft", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "draft" } },
    });
    // v-if false at the root → vue-test-utils v1 reports the wrapper's
    // outer HTML as the empty string.
    expect(w.html()).toBe("");
  });

  it("renders 'Open for comment' label and days-remaining when phase is open", () => {
    const ends = new Date(Date.now() + 16 * 86400000).toISOString();
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: {
          comment_phase: "open",
          comment_period_ends_at: ends,
          pending_comment_count: 12,
        },
      },
      stubs: ["b-alert"],
    });
    expect(w.text()).toContain("Open for comment");
    expect(w.text()).toMatch(/16 days remaining/);
    expect(w.text()).toMatch(/12 pending/);
  });

  it("renders 'Adjudication' label when phase is adjudication", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "adjudication" } },
      stubs: ["b-alert"],
    });
    expect(w.text()).toContain("Adjudication");
  });

  it("uses role=status for screen-reader announcement", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "open" } },
    });
    expect(w.find('[role="status"]').exists()).toBe(true);
  });

  it("emits open-comments-panel when the [Open Comments panel →] link is clicked", async () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: { comment_phase: "open", pending_comment_count: 5 },
      },
    });
    const link = w.findAll("a").wrappers.find((a) => a.text().includes("Open Comments panel"));
    expect(link).toBeDefined();
    await link.trigger("click");
    expect(w.emitted("open-comments-panel")).toBeTruthy();
  });

  it("omits the days-remaining suffix when comment_period_ends_at is missing", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "open" } },
    });
    expect(w.text()).not.toMatch(/days remaining/);
  });

  it("omits the pending-count line when pending_comment_count is missing", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "open" } },
    });
    expect(w.text()).not.toMatch(/pending comments/);
  });
});
