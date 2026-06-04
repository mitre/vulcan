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
    it("delegates to store.triageComment (not direct API call)", async () => {
      const storeResult = { review: { id: 142, triage_status: "concur" } };
      const store = useCommentsStore();
      vi.spyOn(store, "triageComment").mockResolvedValue(storeResult);

      const triage = useCommentTriage();
      const result = await triage.triage(142, { triage_status: "concur" }, 38);

      expect(store.triageComment).toHaveBeenCalledWith(
        142,
        { triage_status: "concur" },
        38,
      );
      expect(triageReview).not.toHaveBeenCalled();
      expect(result).toEqual(storeResult);
    });

    it("sets submitError on failure", async () => {
      const store = useCommentsStore();
      vi.spyOn(store, "triageComment").mockRejectedValue(new Error("409"));

      const triage = useCommentTriage();

      await expect(
        triage.triage(142, { triage_status: "concur" }, 38),
      ).rejects.toThrow("409");

      expect(triage.submitError.value).toBeInstanceOf(Error);
    });
  });

  describe("bulkTriage", () => {
    it("delegates to store.bulkTriage (not direct API call)", async () => {
      const store = useCommentsStore();
      vi.spyOn(store, "bulkTriage").mockResolvedValue({ toast: {} });

      const triage = useCommentTriage();
      await triage.bulkTriage([1, 2, 3], { triage_status: "concur" }, 38);

      expect(store.bulkTriage).toHaveBeenCalledWith(
        [1, 2, 3],
        { triage_status: "concur" },
        38,
      );
      expect(bulkTriageReviews).not.toHaveBeenCalled();
    });
  });
});
