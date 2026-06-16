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
    it("delegates to store.postComment (not direct API call)", async () => {
      const storeResult = { toast: { title: "Posted" } };
      createRuleReview.mockResolvedValue({ data: storeResult });

      const composer = useCommentComposer();
      const store = useCommentsStore();
      vi.spyOn(store, "postComment").mockResolvedValue(storeResult);

      const result = await composer.postComment(38, 100, {
        action: "comment",
        comment: "test",
      });

      expect(store.postComment).toHaveBeenCalledWith(38, 100, {
        action: "comment",
        comment: "test",
      });
      expect(result).toEqual(storeResult);
      expect(composer.submitting.value).toBe(false);
    });

    it("sets submitting=true during request", async () => {
      let resolvePromise;
      const store = useCommentsStore();
      vi.spyOn(store, "postComment").mockReturnValue(
        new Promise((r) => {
          resolvePromise = r;
        }),
      );

      const composer = useCommentComposer();
      const promise = composer.postComment(38, 100, { comment: "x" });

      expect(composer.submitting.value).toBe(true);

      resolvePromise({});
      await promise;
      expect(composer.submitting.value).toBe(false);
    });

    it("sets submitError on failure", async () => {
      const store = useCommentsStore();
      vi.spyOn(store, "postComment").mockRejectedValue(new Error("422"));

      const composer = useCommentComposer();

      await expect(composer.postComment(38, 100, { comment: "x" })).rejects.toThrow("422");

      expect(composer.submitError.value).toBeInstanceOf(Error);
    });
  });

  describe("postComponentComment", () => {
    it("delegates to store.postComponentComment", async () => {
      const store = useCommentsStore();
      vi.spyOn(store, "postComponentComment").mockResolvedValue({ toast: {} });

      const composer = useCommentComposer();
      await composer.postComponentComment(38, { comment: "overall" });

      expect(store.postComponentComment).toHaveBeenCalledWith(38, {
        comment: "overall",
      });
    });
  });

  describe("postReply", () => {
    it("delegates to store.postComment with responding_to_review_id", async () => {
      const store = useCommentsStore();
      vi.spyOn(store, "postComment").mockResolvedValue({});

      const composer = useCommentComposer();
      await composer.postReply(38, 100, 42, "reply text");

      expect(store.postComment).toHaveBeenCalledWith(38, 100, {
        action: "comment",
        comment: "reply text",
        responding_to_review_id: 42,
      });
    });
  });
});
