import { describe, it, expect, vi, beforeEach } from "vitest";
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
    const thread = useCommentThread(38, 42);
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

    const thread = useCommentThread(38, 42);
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

    const thread = useCommentThread(38, 42);
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

    const thread = useCommentThread(38, 42);
    await thread.toggle();
    expect(getReviewResponses).toHaveBeenCalledTimes(1);

    await thread.refresh();
    expect(getReviewResponses).toHaveBeenCalledTimes(2);
  });

  it("sets loadError on fetch failure", async () => {
    getReviewResponses.mockRejectedValue(new Error("boom"));

    const thread = useCommentThread(38, 42);
    await thread.fetch();

    expect(thread.loadError.value).toBe(true);
    expect(thread.loading.value).toBe(false);
  });
});
