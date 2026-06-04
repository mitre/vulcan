import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useCommentComposer } from "@/composables/mutations/useCommentComposer";
import { createRuleReview, createComponentReview } from "@/api/reviewsApi";
import { useCommentsStore } from "@/stores/comments";

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
  createRuleReview: vi.fn(),
  createComponentReview: vi.fn(),
  getReviewResponses: vi.fn(),
  triageReview: vi.fn(),
  bulkTriageReviews: vi.fn(),
}));

describe("useCommentComposer", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it("returns submitting ref and post functions", () => {
    const composer = useCommentComposer();
    expect(composer.submitting.value).toBe(false);
    expect(composer.submitError.value).toBeNull();
    expect(typeof composer.postComment).toBe("function");
    expect(typeof composer.postReply).toBe("function");
    expect(typeof composer.postComponentComment).toBe("function");
  });

  describe("postComment", () => {
    it("calls createRuleReview and invalidates store cache", async () => {
      const response = { data: { toast: { title: "Posted" } } };
      createRuleReview.mockResolvedValue(response);

      const composer = useCommentComposer();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      const result = await composer.postComment(38, 100, {
        action: "comment",
        comment: "test",
      });

      expect(createRuleReview).toHaveBeenCalledWith(100, {
        action: "comment",
        comment: "test",
      });
      expect(store.invalidateCache).toHaveBeenCalledWith(38);
      expect(result).toEqual(response.data);
      expect(composer.submitting.value).toBe(false);
    });

    it("sets submitting=true during request", async () => {
      let resolvePromise;
      createRuleReview.mockReturnValue(
        new Promise((r) => {
          resolvePromise = r;
        }),
      );

      const composer = useCommentComposer();
      const promise = composer.postComment(38, 100, { comment: "x" });

      expect(composer.submitting.value).toBe(true);

      resolvePromise({ data: {} });
      await promise;
      expect(composer.submitting.value).toBe(false);
    });

    it("sets submitError on failure and does NOT invalidate cache", async () => {
      createRuleReview.mockRejectedValue(new Error("422"));

      const composer = useCommentComposer();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      await expect(
        composer.postComment(38, 100, { comment: "x" }),
      ).rejects.toThrow("422");

      expect(composer.submitError.value).toBeTruthy();
      expect(store.invalidateCache).not.toHaveBeenCalled();
    });
  });

  describe("postComponentComment", () => {
    it("calls createComponentReview and invalidates cache", async () => {
      createComponentReview.mockResolvedValue({ data: { toast: {} } });

      const composer = useCommentComposer();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      await composer.postComponentComment(38, { comment: "overall" });

      expect(createComponentReview).toHaveBeenCalledWith(38, {
        comment: "overall",
      });
      expect(store.invalidateCache).toHaveBeenCalledWith(38);
    });
  });

  describe("postReply", () => {
    it("calls createRuleReview with responding_to_review_id", async () => {
      createRuleReview.mockResolvedValue({ data: {} });

      const composer = useCommentComposer();
      await composer.postReply(38, 100, 42, "reply text");

      expect(createRuleReview).toHaveBeenCalledWith(100, {
        action: "comment",
        comment: "reply text",
        responding_to_review_id: 42,
      });
    });
  });
});
