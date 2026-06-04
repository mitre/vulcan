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
    it("maps ALL API response fields to stable camelCase shape", () => {
      const store = useCommentsStore();
      const raw = {
        ...mockCommentsResponse.data.rows[0],
        duplicate_of_review_id: 99,
        addressed_by_rule_id: 200,
        addressed_by_rule_name: "CNTR-01-000050",
        adjudicated_at: "2026-05-01T10:00:00Z",
        commentable_type: "Rule",
        rule_displayed_name: "CNTR-01-000001",
        rule_content: { check: "verify TLS" },
        responding_to_review_id: 50,
        group_rule_displayed_name: "CNTR-01-000001",
        parent_rule_displayed_name: "CNTR-01-000000",
      };

      const n = store.normalizeComment(raw);

      expect(n.id).toBe(142);
      expect(n.authorName).toBe("John Doe");
      expect(n.authorEmail).toBe("john@example.com");
      expect(n.text).toBe("Check text is vague");
      expect(n.section).toBe("check_content");
      expect(n.triageStatus).toBe("pending");
      expect(n.responsesCount).toBe(2);
      expect(n.isImported).toBe(false);
      expect(n.duplicateOfReviewId).toBe(99);
      expect(n.addressedByRuleId).toBe(200);
      expect(n.addressedByRuleName).toBe("CNTR-01-000050");
      expect(n.adjudicatedAt).toBe("2026-05-01T10:00:00Z");
      expect(n.commentableType).toBe("Rule");
      expect(n.ruleDisplayedName).toBe("CNTR-01-000001");
      expect(n.ruleContent).toEqual({ check: "verify TLS" });
      expect(n.respondingToReviewId).toBe(50);
      expect(n.groupRuleDisplayedName).toBe("CNTR-01-000001");
      expect(n.parentRuleDisplayedName).toBe("CNTR-01-000000");
    });

    it("falls back to commenter_display_name when author_name is null", () => {
      const store = useCommentsStore();
      const raw = {
        id: 1,
        author_name: null,
        commenter_display_name: "Fallback Name",
        comment: "test",
      };
      const n = store.normalizeComment(raw);
      expect(n.authorName).toBe("Fallback Name");
    });

    it("defaults to empty string when both author fields are null", () => {
      const store = useCommentsStore();
      const raw = { id: 1, author_name: null, commenter_display_name: null };
      const n = store.normalizeComment(raw);
      expect(n.authorName).toBe("");
    });

    it("defaults null fields safely (no undefined)", () => {
      const store = useCommentsStore();
      const raw = { id: 1 };
      const n = store.normalizeComment(raw);
      expect(n.text).toBe("");
      expect(n.reactions).toEqual({});
      expect(n.responsesCount).toBe(0);
      expect(n.section).toBeNull();
      expect(n.triageStatus).toBeNull();
    });
  });

  describe("commentCount", () => {
    it("sums row counts across all cached entries", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      expect(Object.keys(store.cache)).toHaveLength(1);
      expect(store.commentCount).toBe(1);

      getComments.mockResolvedValue({
        data: {
          rows: [
            { id: 200, comment: "second" },
            { id: 201, comment: "third" },
          ],
          pagination: { total: 2 },
        },
      });
      await store.fetchComments(99, {});
      expect(Object.keys(store.cache)).toHaveLength(2);
      expect(store.commentCount).toBe(3);
    });

    it("returns 0 when cache is empty", () => {
      const store = useCommentsStore();
      expect(store.commentCount).toBe(0);
    });
  });

  describe("fetchReplies", () => {
    it("calls getReviewResponses and returns normalized rows", async () => {
      const mockReplies = {
        data: { rows: [{ id: 7, comment: "reply text" }] },
      };
      getReviewResponses.mockResolvedValue(mockReplies);
      const store = useCommentsStore();

      const result = await store.fetchReplies(38, 42);

      expect(getReviewResponses).toHaveBeenCalledWith(42);
      expect(result.rows).toHaveLength(1);
      expect(result.rows[0].id).toBe(7);
    });

    it("caches replies scoped by componentId + parentReviewId", async () => {
      getReviewResponses.mockResolvedValue({
        data: { rows: [{ id: 7 }] },
      });
      const store = useCommentsStore();

      await store.fetchReplies(38, 42);
      await store.fetchReplies(38, 42);

      expect(getReviewResponses).toHaveBeenCalledTimes(1);
    });

    it("invalidateCache clears reply caches for the component", async () => {
      getReviewResponses.mockResolvedValue({
        data: { rows: [{ id: 7 }] },
      });
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, {});
      await store.fetchReplies(38, 42);
      expect(Object.keys(store.cache)).toHaveLength(2);

      store.invalidateCache(38);
      expect(Object.keys(store.cache)).toHaveLength(0);
    });

    it("invalidateCache does not clear replies for other components", async () => {
      getReviewResponses.mockResolvedValue({
        data: { rows: [{ id: 7 }] },
      });
      const store = useCommentsStore();

      await store.fetchReplies(38, 42);
      await store.fetchReplies(99, 50);

      store.invalidateCache(38);
      expect(Object.keys(store.cache)).toHaveLength(1);
      expect(Object.keys(store.cache)[0]).toMatch(/^99:/);
    });

    it("sets error on failure", async () => {
      getReviewResponses.mockRejectedValue(new Error("fail"));
      const store = useCommentsStore();

      await expect(store.fetchReplies(38, 42)).rejects.toThrow("fail");
      expect(store.error).toBeInstanceOf(Error);
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
      expect(store.error).toBeInstanceOf(Error);
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
      const result = await store.triageComment(38, 142, { triage_status: "concur" });

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
        store.triageComment(38, 142, { triage_status: "concur" }),
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
      await store.bulkTriage(38, [1, 2, 3], { triage_status: "concur" });

      expect(bulkTriageReviews).toHaveBeenCalledWith([1, 2, 3], {
        triage_status: "concur",
      });
      expect(Object.keys(store.cache)).toHaveLength(0);
    });
  });

  describe("cacheKey (private, tested via cache behavior)", () => {
    it("cacheKey is NOT exposed as public store API", () => {
      const store = useCommentsStore();
      expect(store.cacheKey).toBeUndefined();
    });

    it("produces same cache hit for differently-ordered params", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      await store.fetchComments(38, { status: "all", section: "check" });
      await store.fetchComments(38, { section: "check", status: "all" });

      expect(getComments).toHaveBeenCalledTimes(1);
    });
  });
});
