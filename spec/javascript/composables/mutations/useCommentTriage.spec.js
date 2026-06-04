import { describe, it, expect, vi, beforeEach } from "vitest";
import { setActivePinia, createPinia } from "pinia";
import { useCommentTriage } from "@/composables/mutations/useCommentTriage";
import { triageReview, bulkTriageReviews } from "@/api/reviewsApi";
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
  triageReview: vi.fn(),
  bulkTriageReviews: vi.fn(),
  getReviewResponses: vi.fn(),
  createRuleReview: vi.fn(),
  createComponentReview: vi.fn(),
}));

describe("useCommentTriage", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it("returns submitting ref and triage functions", () => {
    const triage = useCommentTriage();
    expect(triage.submitting.value).toBe(false);
    expect(triage.submitError.value).toBeNull();
    expect(typeof triage.triage).toBe("function");
    expect(typeof triage.bulkTriage).toBe("function");
  });

  describe("triage", () => {
    it("calls triageReview and invalidates store cache", async () => {
      const response = {
        data: { review: { id: 142, triage_status: "concur" } },
      };
      triageReview.mockResolvedValue(response);

      const triage = useCommentTriage();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      const result = await triage.triage(142, { triage_status: "concur" }, 38);

      expect(triageReview).toHaveBeenCalledWith(142, {
        triage_status: "concur",
      });
      expect(store.invalidateCache).toHaveBeenCalledWith(38);
      expect(result).toEqual(response.data);
    });

    it("does not invalidate cache on failure", async () => {
      triageReview.mockRejectedValue(new Error("409"));

      const triage = useCommentTriage();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      await expect(
        triage.triage(142, { triage_status: "concur" }, 38),
      ).rejects.toThrow("409");

      expect(store.invalidateCache).not.toHaveBeenCalled();
      expect(triage.submitError.value).toBeTruthy();
    });
  });

  describe("bulkTriage", () => {
    it("calls bulkTriageReviews and invalidates cache", async () => {
      bulkTriageReviews.mockResolvedValue({
        data: { toast: { title: "Triaged 3" } },
      });

      const triage = useCommentTriage();
      const store = useCommentsStore();
      vi.spyOn(store, "invalidateCache");

      await triage.bulkTriage([1, 2, 3], { triage_status: "concur" }, 38);

      expect(bulkTriageReviews).toHaveBeenCalledWith([1, 2, 3], {
        triage_status: "concur",
      });
      expect(store.invalidateCache).toHaveBeenCalledWith(38);
    });
  });
});
