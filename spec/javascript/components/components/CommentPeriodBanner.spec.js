import { describe, it, expect } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentPeriodBanner from "@/components/components/CommentPeriodBanner.vue";

/**
 * The banner only surfaces when there is a deadline worth surfacing —
 * an open component with a future end date (countdown), or a closed
 * component whose recorded end date has already passed (post-deadline
 * notice). Open-without-end-date and open-with-past-end-date are both
 * silent; the inline ComponentCommandBar status badge already
 * communicates "Comments: Open" without consuming banner space.
 */
describe("CommentPeriodBanner", () => {
  const futureEnds = () => new Date(Date.now() + 16 * 86400000).toISOString();
  const pastEnds = () => new Date(Date.now() - 3 * 86400000).toISOString();

  it("renders nothing for an open component without an end date", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "open" } },
    });
    expect(w.html()).toBe("");
  });

  it("renders nothing for an open component whose end date is already in the past", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: { comment_phase: "open", comment_period_ends_at: pastEnds() },
      },
    });
    expect(w.html()).toBe("");
  });

  it("renders nothing for a closed component with no recorded end date", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: { component: { comment_phase: "closed", closed_reason: "adjudicating" } },
    });
    expect(w.html()).toBe("");
  });

  it("renders the open-with-deadline countdown when end date is in the future", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureEnds(),
          pending_comment_count: 12,
        },
      },
      stubs: ["b-alert"],
    });
    expect(w.text()).toContain("Open for comment");
    expect(w.text()).toMatch(/last day to comment/);
    expect(w.text()).toMatch(/16 days left/);
    expect(w.text()).toMatch(/12 pending/);
  });

  it("renders the closed-with-past-deadline notice when closed and end date passed", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: {
          comment_phase: "closed",
          closed_reason: "adjudicating",
          comment_period_ends_at: pastEnds(),
        },
      },
      stubs: ["b-alert"],
    });
    expect(w.text()).toMatch(/Comments closed on/);
  });

  it("uses role=status for screen-reader announcement when rendered", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: { comment_phase: "open", comment_period_ends_at: futureEnds() },
      },
    });
    expect(w.find('[role="status"]').exists()).toBe(true);
  });

  it("emits open-comments-panel when the Open Comments panel button is clicked", async () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureEnds(),
          pending_comment_count: 5,
        },
      },
    });
    const btn = w.find('[data-testid="banner-open-comments-panel"]');
    expect(btn.exists()).toBe(true);
    await btn.trigger("click");
    expect(w.emitted("open-comments-panel")).toBeTruthy();
  });

  it("omits the pending-count line when pending_comment_count is missing", () => {
    const w = mount(CommentPeriodBanner, {
      localVue,
      propsData: {
        component: { comment_phase: "open", comment_period_ends_at: futureEnds() },
      },
    });
    expect(w.text()).not.toMatch(/pending comments/);
  });
});
