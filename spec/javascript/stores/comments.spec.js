import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";
import { getComments } from "@/api/componentsApi";
import {
  triageReview,
  getReviewResponses,
  createRuleReview,
  createComponentReview,
  bulkTriageReviews,
} from "@/api/reviewsApi";

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
  triageReview: vi.fn(),
  getReviewResponses: vi.fn(),
  createRuleReview: vi.fn(),
  createComponentReview: vi.fn(),
  bulkTriageReviews: vi.fn(),
}));

const mockCommentsResponse = {
  data: {
    rows: [
      {
        id: 142,
        rule_id: 7,
        author_name: "John Doe",
        commenter_display_name: "John Doe",
        commenter_email: "john@example.com",
        comment: "Check text is vague",
        section: "check_content",
        triage_status: "pending",
        created_at: "2026-04-27T10:00:00Z",
        reactions: { up: 1, down: 0, mine: null },
        responses_count: 2,
        commenter_imported: false,
      },
    ],
    pagination: { page: 1, per_page: 25, total: 1 },
    status_counts: { pending: 1 },
  },
};

describe("useCommentsStore", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  describe("initial state", () => {
    it("starts with empty cache", () => {
      const store = useCommentsStore();
      expect(store.cache).toEqual({});
    });

    it("starts with loading=false", () => {
      const store = useCommentsStore();
      expect(store.loading).toBe(false);
    });

    it("starts with error=null", () => {
      const store = useCommentsStore();
      expect(store.error).toBeNull();
    });

    it("has the correct store id", () => {
      const store = useCommentsStore();
      expect(store.$id).toBe("comments");
    });
  });

  describe("fetchComments", () => {
    it("calls getComments API and stores normalized camelCase rows in cache", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      const result = await store.fetchComments(38, { triage_status: "all" });

      expect(getComments).toHaveBeenCalledWith(38, { triage_status: "all" });
      expect(result.rows).toHaveLength(1);

      const row = result.rows[0];
      expect(row.id).toBe(142);
      expect(row.authorName).toBe("John Doe");
      expect(row.authorEmail).toBe("john@example.com");
      expect(row.text).toBe("Check text is vague");
      expect(row.section).toBe("check_content");
      expect(row.triageStatus).toBe("pending");
      expect(row.responsesCount).toBe(2);
      expect(row.isImported).toBe(false);

      expect(row.author_name).toBeUndefined();
      expect(row.triage_status).toBeUndefined();

      expect(store.loading).toBe(false);
      expect(store.error).toBeNull();
    });

    it("caches result — second call with same params does not re-fetch", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, { triage_status: "all" });
      await store.fetchComments(38, { triage_status: "all" });

      expect(getComments).toHaveBeenCalledTimes(1);
    });

    it("fetches again with different params", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, { triage_status: "all" });
      await store.fetchComments(38, { triage_status: "pending" });

      expect(getComments).toHaveBeenCalledTimes(2);
    });

    it("sets loading=true during fetch and false after", async () => {
      let resolvePromise;
      getComments.mockReturnValue(
        new Promise((resolve) => {
          resolvePromise = resolve;
        }),
      );
      const store = useCommentsStore();

      const promise = store.fetchComments(38, {});
      expect(store.loading).toBe(true);

      resolvePromise(mockCommentsResponse);
      await promise;
      expect(store.loading).toBe(false);
    });

    it("sets error on API failure and clears loading", async () => {
      const err = new Error("Network error");
      getComments.mockRejectedValue(err);
      const store = useCommentsStore();

      await expect(store.fetchComments(38, {})).rejects.toThrow("Network error");
      expect(store.error).toBe(err);
      expect(store.loading).toBe(false);
    });
  });

  describe("invalidateCache", () => {
    it("clears all cache entries for a given componentId", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, { triage_status: "all" });
      await store.fetchComments(38, { triage_status: "pending" });
      expect(Object.keys(store.cache)).toHaveLength(2);

      store.invalidateCache(38);
      expect(Object.keys(store.cache)).toHaveLength(0);
    });

    it("does not affect cache entries for other componentIds", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      await store.fetchComments(99, {});

      store.invalidateCache(38);
      expect(Object.keys(store.cache)).toHaveLength(1);
      expect(Object.keys(store.cache)[0]).toMatch(/^99:/);
    });
  });

  describe("$reset", () => {
    it("clears all state back to initial values", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      expect(Object.keys(store.cache)).toHaveLength(1);

      store.$reset();
      expect(store.cache).toEqual({});
      expect(store.loading).toBe(false);
      expect(store.error).toBeNull();
    });
  });

  describe("normalizeComment", () => {
    it("maps API response fields to stable shape", () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      const normalized = store.normalizeComment(mockCommentsResponse.data.rows[0]);

      expect(normalized.id).toBe(142);
      expect(normalized.authorName).toBe("John Doe");
      expect(normalized.authorEmail).toBe("john@example.com");
      expect(normalized.text).toBe("Check text is vague");
      expect(normalized.section).toBe("check_content");
      expect(normalized.triageStatus).toBe("pending");
      expect(normalized.responsesCount).toBe(2);
      expect(normalized.isImported).toBe(false);
    });
  });

  describe("fetchReplies", () => {
    it("calls getReviewResponses and returns rows", async () => {
      const mockReplies = {
        data: { rows: [{ id: 7, comment: "reply text" }] },
      };
      getReviewResponses.mockResolvedValue(mockReplies);
      const store = useCommentsStore();

      const result = await store.fetchReplies(42);

      expect(getReviewResponses).toHaveBeenCalledWith(42);
      expect(result.rows).toHaveLength(1);
      expect(result.rows[0].id).toBe(7);
    });

    it("caches replies by parentReviewId", async () => {
      getReviewResponses.mockResolvedValue({
        data: { rows: [{ id: 7 }] },
      });
      const store = useCommentsStore();

      await store.fetchReplies(42);
      await store.fetchReplies(42);

      expect(getReviewResponses).toHaveBeenCalledTimes(1);
    });

    it("sets error on failure", async () => {
      getReviewResponses.mockRejectedValue(new Error("fail"));
      const store = useCommentsStore();

      await expect(store.fetchReplies(42)).rejects.toThrow("fail");
      expect(store.error).toBeTruthy();
    });
  });

  describe("postComment", () => {
    it("calls createRuleReview and invalidates cache", async () => {
      const postResponse = {
        data: { toast: { title: "Posted" } },
      };
      createRuleReview.mockResolvedValue(postResponse);
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      expect(Object.keys(store.cache)).toHaveLength(1);

      const result = await store.postComment(38, 100, {
        comment: "new comment",
      });

      expect(createRuleReview).toHaveBeenCalledWith(100, {
        comment: "new comment",
      });
      expect(result).toEqual(postResponse.data);
      expect(Object.keys(store.cache)).toHaveLength(0);
    });

    it("sets error on failure and does not invalidate cache", async () => {
      createRuleReview.mockRejectedValue(new Error("403"));
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});

      await expect(
        store.postComment(38, 100, { comment: "test" }),
      ).rejects.toThrow("403");
      expect(Object.keys(store.cache)).toHaveLength(1);
      expect(store.error).toBeTruthy();
    });
  });

  describe("postComponentComment", () => {
    it("calls createComponentReview and invalidates cache", async () => {
      createComponentReview.mockResolvedValue({
        data: { toast: { title: "Posted" } },
      });
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      await store.postComponentComment(38, { comment: "overall comment" });

      expect(createComponentReview).toHaveBeenCalledWith(38, {
        comment: "overall comment",
      });
      expect(Object.keys(store.cache)).toHaveLength(0);
    });
  });

  describe("triageComment", () => {
    it("calls triageReview and invalidates cache", async () => {
      triageReview.mockResolvedValue({
        data: { review: { id: 142, triage_status: "concur" } },
      });
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      const result = await store.triageComment(142, { triage_status: "concur" }, 38);

      expect(triageReview).toHaveBeenCalledWith(142, {
        triage_status: "concur",
      });
      expect(result.review.triage_status).toBe("concur");
      expect(Object.keys(store.cache)).toHaveLength(0);
    });

    it("does not invalidate cache on triage failure", async () => {
      triageReview.mockRejectedValue(new Error("409"));
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      await expect(
        store.triageComment(142, { triage_status: "concur" }, 38),
      ).rejects.toThrow("409");
      expect(Object.keys(store.cache)).toHaveLength(1);
    });
  });

  describe("bulkTriage", () => {
    it("calls bulkTriageReviews and invalidates cache", async () => {
      bulkTriageReviews.mockResolvedValue({
        data: { toast: { title: "Triaged 3" } },
      });
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      await store.bulkTriage([1, 2, 3], { triage_status: "concur" }, 38);

      expect(bulkTriageReviews).toHaveBeenCalledWith([1, 2, 3], {
        triage_status: "concur",
      });
      expect(Object.keys(store.cache)).toHaveLength(0);
    });
  });

  describe("cacheKey (exposed for composables)", () => {
    it("returns componentId:JSON key", () => {
      const store = useCommentsStore();
      expect(store.cacheKey(38, { status: "all" })).toBe(
        '38:{"status":"all"}',
      );
    });

    it("handles empty params", () => {
      const store = useCommentsStore();
      expect(store.cacheKey(38, {})).toBe("38:{}");
    });

    it("handles null params", () => {
      const store = useCommentsStore();
      expect(store.cacheKey(38, null)).toBe("38:{}");
    });
  });
});
