import { describe, it, expect, vi, beforeEach } from "vitest";
import { mount } from "@vue/test-utils";
import { setActivePinia, createPinia } from "pinia";
import { localVue } from "@test/testHelper";
import CommentThread from "@/components/shared/CommentThread.vue";
import { getReviewResponses } from "@/api/reviewsApi";

vi.mock("@/api/baseApi", () => ({
  default: {
    get: vi.fn(),
    post: vi.fn(),
    put: vi.fn(),
    patch: vi.fn(),
    delete: vi.fn(),
    defaults: { headers: { common: {} } },
  },
}));

vi.mock("@/api/componentsApi", () => ({
  getComments: vi.fn(),
}));

vi.mock("@/api/reviewsApi", () => ({
  getReviewResponses: vi.fn(),
  createRuleReview: vi.fn(),
  createComponentReview: vi.fn(),
  triageReview: vi.fn(),
  bulkTriageReviews: vi.fn(),
  toggleReaction: vi.fn(),
}));

describe("CommentThread", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    getReviewResponses.mockReset();
  });

  it("does not render the toggle when responses_count is 0", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 0 },
    });
    // The toggle has aria-controls (so screen readers know what it
    // expands); the Reply b-button does not. responses_count=0 means
    // no toggle should render at all.
    expect(w.find("button[aria-controls]").exists()).toBe(false);
  });

  it("renders a singular label for one reply", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    expect(w.text()).toContain("1 reply");
  });

  it("renders a plural label for multiple replies", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 3 },
    });
    expect(w.text()).toContain("3 replies");
  });

  it("emits reply with the parentReviewId when the Reply button is clicked", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 42, responsesCount: 0, canReply: true },
    });
    // With responses_count=0 the only button rendered is Reply.
    await w.find("button").trigger("click");
    expect(w.emitted("reply")).toBeTruthy();
    expect(w.emitted("reply")[0]).toEqual([42]);
  });

  it("hides the Reply button when canReply is false", () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1, canReply: false },
    });
    // Toggle exists but no Reply button
    expect(w.text()).not.toContain("Reply");
    expect(w.text()).toContain("1 reply");
  });

  it("lazy-loads replies on first toggle and caches them", async () => {
    getReviewResponses.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "first reply",
            commenter_display_name: "Replier",
            commenter_imported: false,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });

    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });

    // First click → fetch
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(getReviewResponses).toHaveBeenCalledTimes(1);
    expect(getReviewResponses).toHaveBeenCalledWith(1);
    expect(w.text()).toContain("first reply");

    // Toggle off then on → should NOT refetch (cached)
    await w.find("button[aria-controls]").trigger("click");
    await w.find("button[aria-controls]").trigger("click");
    expect(getReviewResponses).toHaveBeenCalledTimes(1);
  });

  it("calls the correct endpoint for responses", async () => {
    getReviewResponses.mockResolvedValue({ data: { rows: [] } });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 99, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(getReviewResponses).toHaveBeenCalledWith(99);
  });

  it("renders an error state with retry on fetch failure", async () => {
    getReviewResponses.mockRejectedValueOnce(new Error("boom"));
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(w.text()).toContain("Failed to load replies");
  });

  it("invalidates cache + refetches when responsesCount changes while expanded", async () => {
    getReviewResponses.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "first",
            commenter_display_name: "X",
            commenter_imported: false,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(getReviewResponses).toHaveBeenCalledTimes(1);

    // Host's parent re-fetched and the count went up — refetch the thread.
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(getReviewResponses).toHaveBeenCalledTimes(2);
  });

  it("does not refetch on responsesCount change when collapsed (cache cleared lazily)", async () => {
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.setProps({ responsesCount: 2 });
    await new Promise((r) => setTimeout(r, 0));
    expect(getReviewResponses).not.toHaveBeenCalled();
  });

  it("redacts PII fallback names from the server payload (display token only)", async () => {
    getReviewResponses.mockResolvedValue({
      data: {
        rows: [
          {
            id: 7,
            comment: "imported reply",
            commenter_display_name: "(imported commenter)",
            commenter_imported: true,
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    });
    const w = mount(CommentThread, {
      localVue,
      propsData: { parentReviewId: 1, responsesCount: 1 },
    });
    await w.find("button[aria-controls]").trigger("click");
    await new Promise((r) => setTimeout(r, 0));
    expect(w.text()).toContain("(imported commenter)");
    expect(w.text()).toContain("imported");
  });

  describe("b-media structure", () => {
    const twoReplies = {
      data: {
        rows: [
          {
            id: 7,
            comment: "first reply",
            commenter_display_name: "Alice",
            commenter_imported: false,
            created_at: "2026-05-04T00:00:00Z",
          },
          {
            id: 8,
            comment: "second reply",
            commenter_display_name: "Bob",
            commenter_imported: false,
            created_at: "2026-05-04T01:00:00Z",
          },
        ],
      },
    };

    it("wraps each reply in a b-media component", async () => {
      getReviewResponses.mockResolvedValue(twoReplies);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 2 },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      const mediaComponents = w.findAll(".media");
      expect(mediaComponents.length).toBe(2);
    });

    it("renders reply content inside b-media-body", async () => {
      getReviewResponses.mockResolvedValue(twoReplies);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 2 },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      const bodies = w.findAll(".media-body");
      expect(bodies.length).toBe(2);
      expect(bodies.at(0).text()).toContain("first reply");
      expect(bodies.at(1).text()).toContain("second reply");
    });

    it("renders an aside placeholder for future avatar", async () => {
      getReviewResponses.mockResolvedValue(twoReplies);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 2 },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      const asides = w.findAll(".media-aside");
      expect(asides.length).toBe(2);
    });
  });

  // Replies should NOT inherit the parent's triage-status background.
  // Each reply is its own comment — neutral bg unless it has its own status.
  describe("reply triage-status independence", () => {
    const oneReply = {
      data: {
        rows: [
          {
            id: 7,
            comment: "a reply",
            commenter_display_name: "User",
            created_at: "2026-05-04T00:00:00Z",
          },
        ],
      },
    };

    it("does NOT apply the parent's triage-bg class to replies", async () => {
      getReviewResponses.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1, parentTriageStatus: "concur" },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      const replyMedia = w.find(".media");
      expect(replyMedia.classes()).not.toContain("triage-bg--concur");
    });

    it("renders no triage-bg class on replies regardless of parent status", async () => {
      getReviewResponses.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1, parentTriageStatus: "pending" },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      expect(w.find(".media").classes().join(" ")).not.toMatch(/triage-bg--/);
    });

    it("renders no triage-bg class when parentTriageStatus is omitted (default null)", async () => {
      getReviewResponses.mockResolvedValue(oneReply);
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 1 },
      });
      await w.find("button[aria-controls]").trigger("click");
      await new Promise((r) => setTimeout(r, 0));
      expect(w.html()).not.toMatch(/triage-bg--/);
    });
  });

  // ── v2-05f.62.5.2: useCommentThread composable integration ──────────

  describe("composable integration", () => {
    it("uses useCommentReactions composable (not ReactionToggleMixin)", () => {
      const w = mount(CommentThread, {
        localVue,
        propsData: { parentReviewId: 1, responsesCount: 0 },
      });
      expect(w.vm.$options.mixins || []).not.toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            methods: expect.objectContaining({
              submitReactionToggle: expect.any(Function),
            }),
          }),
        ]),
      );
    });
  });
});
