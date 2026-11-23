import { describe, it, expect, vi, beforeEach } from "vitest";
import { ref, nextTick } from "vue";
import { setActivePinia, createPinia } from "pinia";
import { useCommentThread } from "@/composables/useCommentThread";
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
}));

describe("useCommentThread", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it("returns reactive state and methods", () => {
    const thread = useCommentThread(42);
    expect(thread.expanded.value).toBe(false);
    expect(thread.replies.value).toEqual([]);
    expect(thread.loaded.value).toBe(false);
    expect(thread.loading.value).toBe(false);
    expect(thread.loadError.value).toBe(false);
    expect(typeof thread.toggle).toBe("function");
    expect(typeof thread.fetch).toBe("function");
    expect(typeof thread.refresh).toBe("function");
  });

  it("toggle expands and fetches on first expand", async () => {
    getReviewResponses.mockResolvedValue({
      data: { rows: [{ id: 7, comment: "reply" }] },
    });

    const thread = useCommentThread(42);
    await thread.toggle();

    expect(thread.expanded.value).toBe(true);
    expect(getReviewResponses).toHaveBeenCalledWith(42);
    expect(thread.replies.value).toHaveLength(1);
    expect(thread.loaded.value).toBe(true);
  });

  it("toggle collapses without re-fetching (cached)", async () => {
    getReviewResponses.mockResolvedValue({
      data: { rows: [{ id: 7, comment: "reply" }] },
    });

    const thread = useCommentThread(42);
    await thread.toggle();
    expect(thread.expanded.value).toBe(true);

    await thread.toggle();
    expect(thread.expanded.value).toBe(false);
    expect(getReviewResponses).toHaveBeenCalledTimes(1);
  });

  it("refresh clears cache and re-fetches if expanded", async () => {
    getReviewResponses.mockResolvedValue({
      data: { rows: [{ id: 7, comment: "reply" }] },
    });

    const thread = useCommentThread(42);
    await thread.toggle();
    expect(getReviewResponses).toHaveBeenCalledTimes(1);

    await thread.refresh();
    expect(getReviewResponses).toHaveBeenCalledTimes(2);
  });

  it("sets loadError on fetch failure", async () => {
    getReviewResponses.mockRejectedValue(new Error("boom"));

    const thread = useCommentThread(42);
    await thread.fetch();

    expect(thread.loadError.value).toBe(true);
    expect(thread.loading.value).toBe(false);
  });

  // REQUIREMENT: the thread belongs to whichever parent the source names NOW.
  // Hosts reuse one thread instance across comments (the triage split view
  // renders a single CommentThread for whatever comment is active), so a
  // parent captured at call time would pin every later fetch, cache read and
  // invalidation to the first parent — one comment's replies shown under
  // another comment.
  describe("following a reactive parent review id", () => {
    it("fetches the id the source holds now, not the one it was created with", async () => {
      getReviewResponses.mockResolvedValue({ data: { rows: [] } });
      const parentReviewId = ref(42);

      const thread = useCommentThread(parentReviewId);
      parentReviewId.value = 43;
      await nextTick();
      await thread.fetch();

      expect(getReviewResponses).toHaveBeenCalledWith(43);
      expect(getReviewResponses).not.toHaveBeenCalledWith(42);
    });

    it("accepts a getter source (how components pass a prop)", async () => {
      getReviewResponses.mockResolvedValue({ data: { rows: [] } });
      let current = 42;

      const thread = useCommentThread(() => current);
      current = 43;
      await thread.fetch();

      expect(getReviewResponses).toHaveBeenCalledWith(43);
    });

    it("drops the previous parent's replies when the source changes", async () => {
      getReviewResponses.mockResolvedValue({
        data: { rows: [{ id: 7, comment: "reply to 42" }] },
      });
      const parentReviewId = ref(42);

      const thread = useCommentThread(parentReviewId);
      await thread.toggle();
      expect(thread.replies.value).toHaveLength(1);

      parentReviewId.value = 43;
      await nextTick();

      expect(thread.replies.value).toEqual([]);
      expect(thread.loaded.value).toBe(false);
    });

    it("discards an in-flight response for a parent that is no longer current", async () => {
      let resolveStale;
      getReviewResponses.mockImplementationOnce(
        () =>
          new Promise((resolve) => {
            resolveStale = resolve;
          }),
      );
      const parentReviewId = ref(42);

      const thread = useCommentThread(parentReviewId);
      const pending = thread.fetch();
      parentReviewId.value = 43;
      await nextTick();
      resolveStale({ data: { rows: [{ id: 7, comment: "reply to 42" }] } });
      await pending;

      expect(thread.replies.value).toEqual([]);
      expect(thread.loaded.value).toBe(false);
      expect(thread.loading.value).toBe(false);
    });

    it("refresh invalidates and refetches the CURRENT parent", async () => {
      getReviewResponses.mockResolvedValue({ data: { rows: [{ id: 7, comment: "reply" }] } });
      const parentReviewId = ref(42);

      const thread = useCommentThread(parentReviewId);
      await thread.toggle();
      parentReviewId.value = 43;
      await nextTick();
      thread.expanded.value = true;
      await thread.refresh();

      expect(getReviewResponses).toHaveBeenLastCalledWith(43);
    });
  });
});
