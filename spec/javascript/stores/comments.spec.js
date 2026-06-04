import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useCommentsStore } from "@/stores/comments";
import { getComments } from "@/api/componentsApi";
import { triageReview, getReviewResponses } from "@/api/reviewsApi";

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
    it("calls getComments API and stores normalized result in cache", async () => {
      getComments.mockResolvedValue(mockCommentsResponse);
      const store = useCommentsStore();

      const result = await store.fetchComments(38, { triage_status: "all" });

      expect(getComments).toHaveBeenCalledWith(38, { triage_status: "all" });
      expect(result.rows).toHaveLength(1);
      expect(result.rows[0].id).toBe(142);
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
});
