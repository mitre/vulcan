import { describe, it, expect, afterEach, vi } from "vitest";
import { mount } from "@vue/test-utils";
import { localVue } from "@test/testHelper";
import CommentStatusChip from "@/components/shared/CommentStatusChip.vue";

/**
 * CommentStatusChip Requirements:
 *
 * Condensed replacement for CommentPeriodBanner. Renders as a small
 * clickable badge in the command bar instead of a full-width alert row.
 *
 * 1. Shows comment phase status (open/closed/draft)
 * 2. Shows days remaining when open with deadline
 * 3. Shows pending comment count when available
 * 4. Emits click event to open comments panel
 * 5. Returns null when no actionable comment state exists
 */
describe("CommentStatusChip", () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    return mount(CommentStatusChip, {
      localVue,
      propsData: {
        component: {
          id: 41,
          comment_phase: null,
          comment_period_ends_at: null,
          pending_comment_count: 0,
          ...props.component,
        },
        ...props,
      },
    });
  };

  afterEach(() => {
    if (wrapper) wrapper.destroy();
  });

  describe("when comment phase is open with future deadline", () => {
    it("renders the chip with days remaining", () => {
      const futureDate = new Date(Date.now() + 12 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      expect(wrapper.find("[data-testid='comment-status-chip']").exists()).toBe(true);
      expect(wrapper.text()).toMatch(/\d+ days? left/);
    });

    it("shows pending comment count", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 13,
        },
      });
      expect(wrapper.text()).toContain("13");
    });

    it("uses info variant for open phase", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 0,
        },
      });
      const chip = wrapper.find("[data-testid='comment-status-chip']");
      expect(chip.classes()).toContain("btn-outline-info");
    });
  });

  describe("when comment phase is closed with past deadline", () => {
    it("renders the chip with closed status", () => {
      const pastDate = new Date(Date.now() - 5 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "closed",
          comment_period_ends_at: pastDate,
          pending_comment_count: 3,
        },
      });
      expect(wrapper.find("[data-testid='comment-status-chip']").exists()).toBe(true);
      expect(wrapper.text()).toContain("Closed");
    });

    it("uses secondary variant for closed phase", () => {
      const pastDate = new Date(Date.now() - 5 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "closed",
          comment_period_ends_at: pastDate,
          pending_comment_count: 0,
        },
      });
      const chip = wrapper.find("[data-testid='comment-status-chip']");
      expect(chip.classes()).toContain("btn-outline-secondary");
    });
  });

  describe("when no actionable comment state", () => {
    it("does not render when comment_phase is null", () => {
      wrapper = createWrapper({
        component: { comment_phase: null, comment_period_ends_at: null },
      });
      expect(wrapper.find("[data-testid='comment-status-chip']").exists()).toBe(false);
    });

    it("does not render when open but no deadline", () => {
      wrapper = createWrapper({
        component: { comment_phase: "open", comment_period_ends_at: null },
      });
      expect(wrapper.find("[data-testid='comment-status-chip']").exists()).toBe(false);
    });

    it("does not render when open with past deadline", () => {
      const pastDate = new Date(Date.now() - 5 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: pastDate,
        },
      });
      expect(wrapper.find("[data-testid='comment-status-chip']").exists()).toBe(false);
    });
  });

  describe("click behavior", () => {
    it("emits open-comments-panel when clicked", async () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      await wrapper.find("[data-testid='comment-status-chip']").trigger("click");
      expect(wrapper.emitted("open-comments-panel")).toBeTruthy();
    });
  });

  describe("tooltip", () => {
    it("has tooltip when open with deadline", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 5,
        },
      });
      const chip = wrapper.find("[data-testid='comment-status-chip']");
      expect(chip.attributes("title")).toBe("Open comments panel");
    });

    it("has tooltip when closed", () => {
      const pastDate = new Date(Date.now() - 5 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "closed",
          comment_period_ends_at: pastDate,
          pending_comment_count: 3,
        },
      });
      const chip = wrapper.find("[data-testid='comment-status-chip']");
      expect(chip.attributes("title")).toBe("Open comments panel");
    });
  });

  describe("pending count badge", () => {
    it("shows badge when pending count > 0", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 8,
        },
      });
      const badge = wrapper.find(".badge");
      expect(badge.exists()).toBe(true);
      expect(badge.text()).toBe("8");
    });

    it("hides badge when pending count is 0", () => {
      const futureDate = new Date(Date.now() + 7 * 86400000).toISOString();
      wrapper = createWrapper({
        component: {
          comment_phase: "open",
          comment_period_ends_at: futureDate,
          pending_comment_count: 0,
        },
      });
      expect(wrapper.find(".badge").exists()).toBe(false);
    });
  });
});
